defmodule Mix.Tasks.Xaas.Doctor do
  @shortdoc "Machine-readable tree-health census (JSON) for the v26.10.6 campaign"

  @moduledoc """
  Consolidates the ad hoc tree-health re-derivations the campaign keeps doing
  (W760 gate, W755 mock sweep, W760 warnings count) into one real, executed
  check run.

  Emits one JSON document to stdout (when a compile is triggered, Mix compiler
  logs precede it — consumers should parse the LAST non-empty stdout line):

      {"checks": [{"name": ..., "status": "pass" | "fail" | "warn", "detail": ...}]}

  Checks:

    1. `mock_gate` — calls the real `Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage/1`
       over `test/` and `lib/`. FAIL on any hit.
    2. `eu_ai_act_compile` — parses every `.exs` under `test/eu_ai_act/` with
       `Code.string_to_quoted/1`. FAIL on any syntax error. Tradeoff note:
       this is the cheapest check that catches syntax errors; it does NOT
       catch undefined functions/attributes or runtime failures the way a full
       `Code.compile_file`/`mix test` would (full compile would also define
       modules into this VM and re-run doctests — heavier and side-effectful).
    3. `lane_leases` — census of `_build-lane*/` dirs and total bytes.
       Informational; never fails.
    4. `eu_ai_act_file_count` — count of `.exs` files under `test/eu_ai_act/`.
       Expected ~16 files; WARN outside [14, 20].
    5. `eu_ai_act_case_count` — count of literal `test "` declarations
       (regex `^\s*test "`) across those files. PASS in [120, 170]
       (recalibrated per W847 to the honest literal-declaration metric,
       provenance W825; real population 141). The runtime-generated case
       population (~1348 per W778/W815) is reported as an INFORMATIONAL
       detail line (declarations × observed expansion ≈ 9.6×, per W821's
       certified census), never a warn.
    6. `receipt_census` — count of `docs/sjira/v26.10.6/plans/*.md`; WARN if
       any receipt is < 500 bytes (W777 empty-receipt anomaly class), listing
       up to 10 offending filenames.

  Exit code 1 only when check 1 or 2 fails. All commands are real: files are
  actually read, scanned, sized, parsed.
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    checks = [
      mock_gate_check(),
      eu_ai_act_compile_check(),
      lane_lease_check(),
      eu_ai_act_file_count_check(),
      eu_ai_act_case_count_check(),
      receipt_census_check()
    ]

    json = Jason.encode!(%{checks: checks})
    IO.puts(json)

    failing? = Enum.any?(checks, fn c -> c.status == "fail" end)
    if failing?, do: Mix.shell().error("xaas.doctor: FAIL (see JSON above)")

    if failing?, do: exit({:shutdown, 1})
  end

  # 1. Mock gate — real scan, real banned-regex over real files.
  defp mock_gate_check do
    hits = Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"])

    case hits do
      [] ->
        %{name: "mock_gate", status: "pass", detail: "0 banned-mock hits in test/ and lib/"}

      hits ->
        %{name: "mock_gate", status: "fail",
          detail: "#{length(hits)} banned-mock hits: " <> Enum.join(hits, " | ")}
    end
  end

  # 2. eu_ai_act compile gate — syntax parse of every test file.
  defp eu_ai_act_compile_check do
    files = Path.wildcard("test/eu_ai_act/**/*.exs")

    {results, _ms} =
      Enum.map_reduce(files, 0, fn path, acc ->
        t0 = System.monotonic_time(:millisecond)

        result =
          path
          |> File.read!()
          |> Code.string_to_quoted()

        case result do
          {:ok, _quoted} -> {nil, acc + (System.monotonic_time(:millisecond) - t0)}
          {:error, {meta, msg, _tok}} ->
            line = if is_list(meta), do: Keyword.get(meta, :line), else: meta
            {{path, line, msg}, acc + (System.monotonic_time(:millisecond) - t0)}
        end
      end)

    errors = Enum.reject(results, &is_nil/1)

    case errors do
      [] ->
        %{name: "eu_ai_act_compile", status: "pass",
          detail: "#{length(files)} .exs files parsed clean (syntax-level)"}

      errs ->
        %{name: "eu_ai_act_compile", status: "fail",
          detail: Enum.map_join(errs, " | ", fn {p, l, m} -> "#{p}:#{l}: #{m}" end)}
    end
  end

  # 3. Lane-lease census — informational.
  defp lane_lease_check do
    lanes = Path.wildcard("_build-lane*")

    {sizes, total_bytes} =
      Enum.map_reduce(lanes, 0, fn lane, acc ->
        bytes = dir_size(lane)
        {{lane, bytes}, acc + bytes}
      end)

    %{name: "lane_leases", status: "pass",
      detail: "#{length(lanes)} _build-lane*/ dir(s), #{total_bytes} total bytes: " <>
                Enum.map_join(sizes, ", ", fn {k, v} -> "#{k}=#{v}B" end)}
  end

  # 4. eu_ai_act test file count — expected ~16 files (band against FILES).
  defp eu_ai_act_file_count_check do
    n = count_exs("test/eu_ai_act")

    cond do
      n >= 14 and n <= 20 ->
        %{name: "eu_ai_act_file_count", status: "pass",
          detail: "#{n} .exs files (band 14..20)"}

      true ->
        %{name: "eu_ai_act_file_count", status: "warn",
          detail: "#{n} .exs files outside expected band 14..20"}
    end
  end

  # 5. eu_ai_act test-case census — literal `test "` declarations.
  #    Band is on DECLARATIONS (per W847, provenance W825: real count 141).
  #    The runtime-generated population (~1348, W778/W815; expansion ~9.6x per
  #    W821's certified census) is informational only — never a warn.
  @test_decl_regex ~r/^\s*test "/m
  @case_band_low 120
  @case_band_high 170
  # W821 certified census: ~1348 runtime cases from 141 declarations ≈ 9.6x.
  @observed_expansion 9.6

  defp eu_ai_act_case_count_check do
    files = Path.wildcard("test/eu_ai_act/**/*.exs")

    n =
      Enum.reduce(files, 0, fn path, acc ->
        acc + length(Regex.scan(@test_decl_regex, File.read!(path)))
      end)

    expansion_note =
      "declarations × observed expansion ≈ #{Float.round(n * @observed_expansion, 1)} " <>
        "estimated runtime cases (~9.6x per W821 certified census)"

    cond do
      n >= @case_band_low and n <= @case_band_high ->
        %{name: "eu_ai_act_case_count", status: "pass",
          detail: "#{n} literal test declarations (band 120..170, provenance W825/W847); " <>
                    expansion_note}

      true ->
        %{name: "eu_ai_act_case_count", status: "warn",
          detail: "#{n} literal test declarations outside band 120..170 " <>
                    "(provenance W825/W847); " <> expansion_note}
    end
  end

  # 6. Receipt census — count + empty-receipt detector (< 500 bytes),
  #    listing up to 10 offending filenames.
  defp receipt_census_check do
    receipts = Path.wildcard("docs/sjira/v26.10.6/plans/*.md")

    undersized =
      receipts
      |> Enum.map(fn p -> {p, File.stat!(p).size} end)
      |> Enum.filter(fn {_p, size} -> size < 500 end)

    case undersized do
      [] ->
        %{name: "receipt_census", status: "pass",
          detail: "#{length(receipts)} receipts, none < 500 bytes"}

      undersized ->
        shown = Enum.take(undersized, 10)

        %{name: "receipt_census", status: "warn",
          detail: "#{length(receipts)} receipts; #{length(undersized)} < 500 bytes: " <>
                    Enum.map_join(shown, ", ", fn {p, s} -> "#{p}=#{s}B" end) <>
                    if(length(undersized) > 10, do: " (+#{length(undersized) - 10} more)", else: "")}
    end
  end

  defp count_exs(dir), do: length(Path.wildcard(Path.join(dir, "**/*.exs")))

  defp dir_size(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        Enum.reduce(entries, 0, fn entry, acc ->
          path = Path.join(dir, entry)

          acc +
            if File.dir?(path) do
              dir_size(path)
            else
              case File.stat(path) do
                {:ok, %{size: s}} -> s
                _ -> 0
              end
            end
        end)

      _ ->
        0
    end
  end
end
