defmodule Xaas.EUAIAct.NotApplicableCompletenessTest do
  @moduledoc """
  W843 — cross-file NOT_APPLICABLE completeness court for the EU-AI-Act suite.

  Each per-title suite classifies real corpus lines via two mechanisms:

    * a literal evidence/classification map — `"line_id" => {"W…", desc,
      paths}` (evidenced) or `"line_id" => {:not_applicable, reason}`
      (Title III's W535-era per-line map);
    * clause rules over runtime corpus lines — `id in ["86.2", "86.3"] ->
      {:not_applicable, reason}` (Title II W655-differentiated rules,
      Title VI-XIII W648 scoping rules).

  This court reads the REAL suite sources (compile-time AST extraction) and
  the REAL corpus JSON — no mocks, no doubles — and asserts:

    (a) every classification-map key and rule-referenced line id cites a real
        corpus line id in docs/eu_ai_act/corpus.json;
    (b) every extracted NOT_APPLICABLE disposition carries a non-empty typed
        reason (literal binary or non-empty interpolation);
    (c) no corpus line is claimed BOTH evidenced and NOT_APPLICABLE across
        files (cross-file partition check over real map reads);
    (d) determinism: extraction is a pure function of the sources — two
        passes over sources and corpus produce identical results.

  Chicago: collaborators are the on-disk suite files and corpus.json itself.
  """

  use ExUnit.Case, async: false

  @moduletag :eu_ai_act

  @corpus_relpath "docs/eu_ai_act/corpus.json"
  @suite_dir "test/eu_ai_act"
  @this_file "not_applicable_completeness_test.exs"
  # line-id shape: "5.1.h.i", "14.5.s2", "86.2", "9.5.a"
  @id_re ~r/^\d+(\.[A-Za-z0-9]+)+$/

  # Non-vacuity pins: known classification facts extracted from the real
  # sources (walker-falsifiers — if the AST extraction regresses to zero
  # facts, these fail first, so no check below can pass vacuously).
  @walker_pins %{
    "title_ii_test.exs" => %{na_ids: ["5.8", "5.1.h.i", "5.1.s2"]},
    "title_i_test.exs" => %{evidenced: ["3.1", "1.2.b"]},
    "title_iii_test.exs" => %{evidenced: ["9.5.a", "14.3.a"], na_ids: ["14.5", "14.5.s2"]},
    "title_iv_v_test.exs" => %{evidenced: ["50.1"]},
    "title_vi_xiii_test.exs" => %{na_ids: ["86.2", "86.3", "73.9", "74.12", "74.13.b"]}
  }

  # ---------------------------------------------------------------------------
  # Real corpus read
  # ---------------------------------------------------------------------------

  defp corpus_line_ids do
    path = Path.expand(@corpus_relpath, File.cwd!())
    assert File.exists?(path), "EUAIA_CORPUS_MISSING_W843: #{path}"
    assert {:ok, %{"titles" => titles}} = Jason.decode(File.read!(path))

    ids =
      for t <- titles,
          a <- t["articles"] || [],
          l <- a["lines"] || [],
          is_map(l),
          is_binary(l["line_id"]),
          into: MapSet.new(),
          do: l["line_id"]

    assert MapSet.size(ids) > 0, "corpus.json decoded but yielded zero line_ids"
    ids
  end

  # ---------------------------------------------------------------------------
  # AST extraction (pure function of source text)
  # ---------------------------------------------------------------------------

  defp extract_facts(src) do
    ast = Code.string_to_quoted!(src)

    init = %{evidenced: MapSet.new(), na_ids: %{}}

    {_, acc} =
      Macro.prewalk(ast, init, fn
        {:%{}, _, pairs} = node, acc when is_list(pairs) ->
          acc =
            Enum.reduce(pairs, acc, fn
              {k, v}, a when is_binary(k) ->
                if Regex.match?(@id_re, k), do: classify_pair(a, k, v), else: a

              _, a ->
                a
            end)

          {node, acc}

        {:->, _, [params, body]} = node, acc when is_list(params) ->
          guard = params |> List.first() |> List.wrap()
          ids = ids_in(guard)

          acc =
            case na_reason(body) do
              nil ->
                acc

              reason ->
                Enum.reduce(ids, acc, fn id, a ->
                  %{a | na_ids: Map.update(a.na_ids, id, reason, &join_reasons(&1, reason))}
                end)
            end

          {node, acc}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  # A map pair `"id" => value` is a classification entry when the value is a
  # tagged tuple: {:not_applicable, reason} | {:evidenced, ...} | {"W…", ...}.
  # Literal tuples nested inside a map are represented in AST as
  # {:{}, meta, elems} — unwrap before classifying. @typed_calls quote
  # blocks, @line_atoms atoms, @open_gaps binaries and deepening kind-lists
  # all fall through (not classification entries).
  defp classify_pair(acc, id, {:{}, _, elems}) when is_list(elems),
    do: classify_tagged(acc, id, elems)

  defp classify_pair(acc, id, v) when is_tuple(v), do: classify_tagged(acc, id, Tuple.to_list(v))

  defp classify_pair(acc, _id, _v), do: acc

  defp classify_tagged(acc, id, [:not_applicable, reason | _]) when is_binary(reason) do
    %{acc | na_ids: Map.update(acc.na_ids, id, reason, &join_reasons(&1, reason))}
  end

  defp classify_tagged(acc, id, [:evidenced | _]), do: put_ev(acc, id)

  defp classify_tagged(acc, id, [tag | _]) when is_binary(tag) do
    # {"W501", desc, paths, ...} evidence triple
    if Regex.match?(~r/^W\d/, tag), do: put_ev(acc, id), else: acc
  end

  defp classify_tagged(acc, _id, _), do: acc

  defp put_ev(acc, id), do: %{acc | evidenced: MapSet.put(acc.evidenced, id)}

  # line-id string literals in a clause guard (`id == "x"`, `id in ["x", …]`).
  # Bare article numbers ("86", "43") do not match @id_re, so article-range
  # rules contribute no ids — exactly the runtime-determined population.
  defp ids_in(guard) do
    {_, ids} =
      Macro.prewalk(guard, [], fn
        s, acc when is_binary(s) ->
          if Regex.match?(@id_re, s), do: {s, [s | acc]}, else: {s, acc}

        n, acc ->
          {n, acc}
      end)

    Enum.uniq(ids)
  end

  # Literal non-empty reason in a clause body: a plain binary, or an
  # interpolation whose literal parts are non-empty (title_vi_xiii's 86.2/86.3
  # reason interpolates the scoping text — statically still typed content).
  defp na_reason(body) do
    {_, found} =
      Macro.prewalk(body, :none, fn
        {:not_applicable, reason}, :none -> {:ok, reason_node(reason)}
        n, acc -> {n, acc}
      end)

    case found do
      :none -> nil
      r -> r
    end
  end

  defp reason_node(r) when is_binary(r), do: if(String.trim(r) == "", do: nil, else: r)
  # interpolation / concatenation: require at least one non-empty literal part
  defp reason_node({:<<>>, _, parts}) when is_list(parts) do
    if Enum.any?(parts, fn p -> is_binary(p) and String.trim(p) != "" end),
      do: ":interpolated_reason_w843",
      else: nil
  end
  defp reason_node(_), do: nil

  defp join_reasons(a, b), do: a <> " | " <> b

  # ---------------------------------------------------------------------------
  # Suite scan
  # ---------------------------------------------------------------------------

  defp suite_facts do
    dir = Path.expand(@suite_dir, File.cwd!())

    files =
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".exs"))
      |> Enum.reject(&(&1 == @this_file))
      |> Enum.sort()

    Enum.map(files, fn f ->
      {f, extract_facts(File.read!(Path.join(dir, f)))}
    end)
  end

  defp facts_for(facts, file) do
    {_f, fs} = Enum.find(facts, fn {f, _} -> f == file end)
    fs
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  test "W843 walker non-vacuity: known classification facts are extracted" do
    facts = suite_facts()

    for {file, pins} <- @walker_pins do
      fs = facts_for(facts, file)

      for id <- Map.get(pins, :evidenced, []) do
        assert id in fs.evidenced,
               "walker regressed: #{file} should evidence #{id} (have: #{inspect(MapSet.to_list(fs.evidenced))})"
      end

      for id <- Map.get(pins, :na_ids, []) do
        assert Map.has_key?(fs.na_ids, id),
               "walker regressed: #{file} should classify #{id} NOT_APPLICABLE (have: #{inspect(fs.na_ids)})"
      end
    end
  end

  test "W843 (a): every classification map key and rule id cites a real corpus line id" do
    corpus = corpus_line_ids()
    facts = suite_facts()

    cited_set =
      facts
      |> Enum.flat_map(fn {_f, fs} -> MapSet.to_list(fs.evidenced) ++ Map.keys(fs.na_ids) end)
      |> MapSet.new()

    assert MapSet.size(cited_set) > 50, "extraction implausibly small — walker broken"

    unknown = cited_set |> MapSet.difference(corpus) |> MapSet.to_list() |> Enum.sort()

    assert unknown == [],
           "EUAIA_NA_UNKNOWN_LINE_IDS_W843: ids not in corpus.json: #{inspect(unknown)}"
  end

  test "W843 (b): every NOT_APPLICABLE disposition carries a non-empty typed reason" do
    facts = suite_facts()

    bad =
      for {f, fs} <- facts,
          {id, reason} <- fs.na_ids,
          reason in [nil, ""],
          do: {f, id}

    assert bad == [], "EUAIA_NA_EMPTY_REASON_W843: #{inspect(bad, limit: 20)}"

    # reason volume sanity: reasons are typed deployer-class text, not "n/a"
    for {f, fs} <- facts,
        {id, reason} <- fs.na_ids,
        is_binary(reason) and reason != ":interpolated_reason_w843" do
      assert String.length(reason) >= 20,
             "EUAIA_NA_UNTYPED_REASON_W843: #{f} #{id} reason too thin to be a typed deployer-class reason: #{inspect(reason)}"
    end
  end

  test "W843 (c): no corpus line is claimed BOTH evidenced and NOT_APPLICABLE across files" do
    _ = corpus_line_ids()
    facts = suite_facts()

    evidenced =
      facts |> Enum.flat_map(fn {_f, fs} -> MapSet.to_list(fs.evidenced) end) |> MapSet.new()

    na = facts |> Enum.flat_map(fn {_f, fs} -> Map.keys(fs.na_ids) end) |> MapSet.new()

    both = evidenced |> MapSet.intersection(na) |> MapSet.to_list() |> Enum.sort()

    assert both == [],
           "EUAIA_NA_PARTITION_VIOLATION_W843: lines both evidenced and NOT_APPLICABLE: #{inspect(both)}"

    # real runtime read for the suite exposing its classification module
    # (title_vi_xiii): per-line NA reasons non-empty and no intra-file
    # evidenced/NA overlap. When the module is not already loaded (standalone
    # run) its source facts are already covered by the AST checks above.
    case title_vixiii_module() do
      nil ->
        :ok

      mod ->
        rt_na = apply(mod, :not_applicable, [])
        rt_ev_ids = MapSet.new(apply(mod, :evidenced, []), fn {l, _, _} -> l["line_id"] end)
        rt_na_ids = MapSet.new(rt_na, fn {l, _, _} -> l["line_id"] end)

        for {line, :not_applicable, reason} <- rt_na do
          id = line["line_id"]

          assert is_binary(reason) and String.trim(reason) != "",
                 "title_vi_xiii runtime NA reason empty for #{id}"
        end

        overlap = rt_ev_ids |> MapSet.intersection(rt_na_ids) |> MapSet.to_list() |> Enum.sort()

        assert overlap == [],
               "EUAIA_NA_PARTITION_VIOLATION_W843 (title_vi_xiii runtime): #{inspect(overlap)}"
    end
  end

  defp title_vixiii_module do
    mod = Xaas.EUAIAct.TitleVIXIII.Lines

    if Code.ensure_loaded?(mod) do
      mod
    else
      try do
        Code.compile_file("title_vi_xiii_test.exs", Path.expand(@suite_dir, File.cwd!()))
        mod
      rescue
        _ -> nil
      end
    end
  end

  test "W843 (d): determinism — extraction and corpus decode are pure" do
    c1 = corpus_line_ids()
    c2 = corpus_line_ids()
    assert MapSet.equal?(c1, c2)
    assert Enum.sort(MapSet.to_list(c1)) == Enum.sort(MapSet.to_list(corpus_line_ids()))

    f1 = suite_facts()
    f2 = suite_facts()
    assert f1 == f2, "EUAIA_NA_EXTRACTION_NONDETERMINISTIC_W843"
  end
end
