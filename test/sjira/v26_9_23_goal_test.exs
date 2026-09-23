defmodule Xaas.Sjira.V26923GoalTest do
  @moduledoc """
  Chicago-style qualification of the GC-26.9.23 governing object (lane V23-P):
  the real docs/sjira/v26.9.23/{prd-ard.md,goal.ttl,stop.rq,courts/*.sh}
  parsed with RDF.ex and read byte for byte, the real `mix xaas.stop_court`
  run as a separate OS process, the real `~/.claude/dfcm/validate_receipt.py`
  (a real `python3` process), the real oxigraph NIF evaluating the real
  stop.rq, and real tmp git repositories for the fixture courts. No mocks, no
  stubs. Independent witnesses: tuple digests are recomputed by Python's
  `json.dumps`, and the stop.rq property-path semantics are cross-checked
  against rdflib's native ASK (named skip when rdflib is absent).
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Xaas.StopCourt

  @repo Path.expand("../..", __DIR__)
  @dir Path.join(@repo, "docs/sjira/v26.9.23")
  @goal_ttl Path.join(@dir, "goal.ttl")
  @stop_rq Path.join(@dir, "stop.rq")
  @prose Path.join(@dir, "prd-ard.md")
  @friday_goal Path.join(@repo, "docs/sjira/v26.9.22/friday/goal.ttl")
  @accepted_prose "/Users/sac/wt/v26922/v26923/prd-ard.md"
  @validator Path.expand("~/.claude/dfcm/validate_receipt.py")

  @prose_sha256 "7c8797b2bc9130fc4c8fce9138cc8140cb704e0633715807398451c660658212"
  @prose_bytes 39_386

  @sj "https://ggen-igniter.dev/ontology/semantic-jira#"
  @v23 "https://ggen-igniter.dev/sjira/v26.9.23#"
  @fri "https://ggen-igniter.dev/sjira/v26.9.22/friday#"
  @dct "http://purl.org/dc/terms/"
  @rdfs "http://www.w3.org/2000/01/rdf-schema#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  if not File.regular?(@validator) do
    @moduletag skip: "needs ~/.claude/dfcm/validate_receipt.py (the fleet R-schema validator)"
  end

  @rdflib System.cmd("python3", ["-c", "import rdflib"], stderr_to_stdout: true) |> elem(1) == 0

  # Gate -> boundary class (V23-P task), Friday gates it subsumes, ARD section 26 falsifiers.
  @gates %{
    0 => {"FirstMile", ["G0", "G1"], []},
    1 => {"Bootstrap", ["G2"], []},
    2 => {"FirstMile", ["G3"], []},
    3 => {"FirstMile", ["G4"], ["F1"]},
    4 => {"Core", ["G5"], ["F2"]},
    5 => {"Core", ["G6"], ["F3"]},
    6 => {"LastMile", ["G7"], ["F4"]},
    7 => {"LastMile", ["G7"], []},
    8 => {"LastMile", ["G8"], []},
    9 => {"Core", ["G9"], []},
    10 => {"Bootstrap", ["G10"], ["F5", "F6"]},
    11 => {"Core", ["G11"], ["F7"]},
    12 => {"Core", [], []}
  }

  # DRIVER.md gate map: lane -> {repository, sj:checkpointOf}.
  @lanes %{
    "V23-P" => {"xaas", "GC23-0"},
    "V23-X" => {"xaas", "GC23-0"},
    "V23-F" => {"xaas", "GC23-11"},
    "V23-C" => {"ggen_igniter", "GC23-2"},
    "V23-B" => {"ggen_igniter", "GC23-1"},
    "V23-D" => {"xaas", "GC23-5"},
    "V23-R" => {"xaas", "GC23-10"},
    "V23-M" => {"xaas", "GC23-9"},
    "V23-H" => {"xaas", "GC23-12"},
    "V23-W" => {"xaas", "GC-26.9.24"},
    "V23-Q" => {"xaas", "GC-26.9.23"}
  }

  @successor_policy "discovered work that falsifies no GC23 proposition -> v23:GC-26.9.24"

  # ------------------------------------------------------------------ helpers

  defp graph, do: RDF.Turtle.read_file!(@goal_ttl)
  defp iri(ns, local), do: RDF.iri(ns <> local)
  defp desc(graph, iri), do: RDF.Graph.description(graph, iri)
  defp get(graph, subject, pred), do: graph |> desc(subject) |> RDF.Description.get(pred, [])
  defp strings(graph, subject, pred), do: graph |> get(subject, pred) |> Enum.map(&lexical/1)

  defp lexical(%RDF.Literal{} = literal), do: RDF.Literal.lexical(literal)
  defp lexical(term), do: to_string(term)

  defp one(graph, subject, pred) do
    assert [value] = strings(graph, subject, pred), "#{subject} #{pred}: expected exactly one"
    value
  end

  defp typed(graph, class) do
    for {s, p, o} <- RDF.Graph.triples(graph),
        to_string(p) == @rdf_type and to_string(o) == class,
        uniq: true,
        do: s
  end

  defp by_identifier(graph, class) do
    Map.new(typed(graph, class), fn s -> {one(graph, s, iri(@dct, "identifier")), s} end)
  end

  defp prose, do: File.read!(@prose)

  defp validate(paths) do
    {out, code} = System.cmd("python3", [@validator | paths], stderr_to_stdout: true)
    {code, out}
  end

  defp python_digest(tuple) do
    script = """
    import hashlib, json, sys
    t = json.loads(sys.argv[1]); t["exclusions"] = sorted(t["exclusions"])
    b = json.dumps(t, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    print("sha256:" + hashlib.sha256(b).hexdigest())
    """

    {out, 0} = System.cmd("python3", ["-c", script, Jason.encode!(tuple)])
    String.trim(out)
  end

  defp tmp_dir(prefix) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp head(repo) do
    {sha, 0} = System.cmd("git", ["-C", repo, "rev-parse", "HEAD"])
    String.trim(sha)
  end

  # ------------------------------------------------------------------ the accepted prose

  test "prd-ard.md is the accepted prose, byte-identical (sha256 and length pinned)" do
    bytes = prose()
    assert byte_size(bytes) == @prose_bytes
    assert Base.encode16(:crypto.hash(:sha256, bytes), case: :lower) == @prose_sha256

    if File.regular?(@accepted_prose) do
      assert File.read!(@accepted_prose) == bytes
    end
  end

  # ------------------------------------------------------------------ goal.ttl structure

  test "goal.ttl parses with RDF.ex; the root's sj:stopQuery is byte-equal (trimmed) to stop.rq" do
    g = graph()
    roots = by_identifier(g, @sj <> "GoalCheckpoint")
    root = Map.fetch!(roots, "GC-26.9.23")

    assert String.trim(one(g, root, iri(@sj, "stopQuery"))) == String.trim(File.read!(@stop_rq))
    assert {:ok, _select} = StopCourt.ask_as_select(File.read!(@stop_rq))
    assert one(g, root, iri(@sj, "courtCommand")) == "mix xaas.stop_court --checkpoint GC-26.9.23"
    assert get(g, root, iri(@sj, "successorOf")) == [iri(@fri, "GC-FRI-0800")]
    assert get(g, root, iri(@sj, "successorCheckpoint")) == [iri(@v23, "GC-26.9.24")]
    assert one(g, root, iri(@sj, "sourceSha256")) == "sha256:" <> @prose_sha256
    assert one(g, root, iri(@sj, "successorPolicy")) =~ "F8 (ARD section 26)"
    assert one(g, root, iri(@sj, "successorPolicy")) =~ @successor_policy

    falsifiers = get(g, root, iri(@sj, "falsifier"))

    assert Enum.any?(falsifiers, fn f ->
             one(g, f, iri(@dct, "description")) |> String.starts_with?("F8 (ARD section 26)")
           end)

    # PRD section 13 is the root's description.
    assert one(g, root, iri(@dct, "description")) =~ "RequiredUnknown = ∅"

    assert one(g, root, iri(@dct, "description")) =~
             "Additional capability becomes v26.9.24+ work."
  end

  test "one root sj:exclusion per PRD section 10 non-goal, verbatim" do
    g = graph()
    root = iri(@v23, "GC-26.9.23")
    exclusions = strings(g, root, iri(@sj, "exclusion"))

    [_, section] = String.split(prose(), "# 10. Non-Goals", parts: 2)
    [section, _] = String.split(section, "# 11. Success Metrics", parts: 2)

    non_goals =
      ~r/^\* (.+?)[;.]$/m
      |> Regex.scan(section, capture: :all_but_first)
      |> List.flatten()

    assert length(non_goals) == 12
    assert length(exclusions) == 12

    for non_goal <- non_goals do
      assert Enum.count(exclusions, &String.ends_with?(&1, ": " <> non_goal <> ".")) == 1,
             "no root exclusion for PRD section 10 non-goal #{inspect(non_goal)}"
    end
  end

  test "exactly 13 gates GC23-0..GC23-12, each with its court script, boundary class, PRD section 12 text, acceptance and falsifier" do
    g = graph()
    root = iri(@v23, "GC-26.9.23")

    gates =
      for s <- typed(g, @sj <> "GoalCheckpoint"),
          root in get(g, s, iri(@sj, "checkpointOf")),
          into: %{},
          do: {one(g, s, iri(@dct, "identifier")), s}

    assert Map.keys(gates) |> Enum.sort() == Enum.map(0..12, &"GC23-#{&1}") |> Enum.sort()

    section12 =
      ~r/^### (GC23-\d+) — [^\n]+\n\n([^\n]+)$/mu
      |> Regex.scan(prose(), capture: :all_but_first)
      |> Map.new(fn [id, text] -> {id, text} end)

    assert map_size(section12) == 13

    for {n, {boundary, friday, f_ids}} <- @gates do
      id = "GC23-#{n}"
      gate = Map.fetch!(gates, id)

      assert one(g, gate, iri(@sj, "courtCommand")) == "sh docs/sjira/v26.9.23/courts/#{id}.sh"
      assert get(g, gate, iri(@sj, "boundaryClass")) == [iri(@sj, boundary)], id
      assert one(g, gate, iri(@dct, "description")) == Map.fetch!(section12, id)
      assert File.regular?(Path.join(@repo, "docs/sjira/v26.9.23/courts/#{id}.sh"))

      assert [acceptance] = get(g, gate, iri(@sj, "acceptance"))
      assert one(g, acceptance, iri(@dct, "description")) =~ ~r/\S/
      falsifiers = get(g, gate, iri(@sj, "falsifier"))
      assert falsifiers != []

      falsifier_texts = Enum.map(falsifiers, &one(g, &1, iri(@dct, "description")))

      for f <- f_ids do
        assert Enum.any?(falsifier_texts, &String.starts_with?(&1, "#{f} (ARD section 26)")),
               "#{id} lacks #{f}"
      end

      see_also = get(g, gate, iri(@rdfs, "seeAlso")) |> Enum.map(&to_string/1) |> Enum.sort()
      assert see_also == Enum.map(friday, &(@fri <> &1)) |> Enum.sort(), id
    end
  end

  test "the successor bucket GC-26.9.24 is false by construction and folds in fri:GC-026923" do
    g = graph()
    bucket = iri(@v23, "GC-26.9.24")

    assert one(g, bucket, iri(@dct, "identifier")) == "GC-26.9.24"
    assert get(g, bucket, iri(@sj, "successorOf")) == [iri(@v23, "GC-26.9.23")]
    assert get(g, bucket, iri(@sj, "boundaryClass")) == [iri(@sj, "Successor")]
    assert iri(@fri, "GC-026923") in get(g, bucket, iri(@rdfs, "seeAlso"))
    assert one(g, bucket, iri(@sj, "stopQuery")) =~ ~r/ASK \{ FILTER\(false\) \}\s*\z/
    assert get(g, bucket, iri(@sj, "checkpointOf")) == []
  end

  test "graph law: no asserted receipt, and every sj:standing literal is the UNKNOWN placeholder" do
    g = graph()

    for {s, p, o} <- RDF.Graph.triples(g) do
      refute to_string(p) == @sj <> "receipt", "#{s} asserts sj:receipt"

      refute to_string(p) == @rdf_type and to_string(o) == @sj <> "Receipt",
             "#{s} is a sj:Receipt"

      if to_string(p) == @sj <> "standing" do
        assert lexical(o) == "UNKNOWN", "#{s} declares standing #{lexical(o)}"
      end
    end
  end

  test "every fri: node goal.ttl references is typed in the predecessor Friday goal graph" do
    g = graph()
    friday = RDF.Turtle.read_file!(@friday_goal)

    referenced =
      for {_s, _p, o} <- RDF.Graph.triples(g),
          match?(%RDF.IRI{}, o),
          String.starts_with?(to_string(o), @fri),
          uniq: true,
          do: o

    assert length(referenced) >= 13

    for node <- referenced do
      assert RDF.Graph.describes?(friday, node), "#{node} is not defined in #{@friday_goal}"
      assert desc(friday, node) |> RDF.Description.get(RDF.iri(@rdf_type), []) != []
    end
  end

  # ------------------------------------------------------------------ lane work orders

  test "one tuple-complete WorkOrder per DRIVER.md lane, under the gate it serves" do
    g = graph()
    orders = by_identifier(g, @sj <> "WorkOrder")
    checkpoints = by_identifier(g, @sj <> "GoalCheckpoint")

    assert Map.keys(orders) |> Enum.sort() == Map.keys(@lanes) |> Enum.sort()

    for {lane, {repo, checkpoint}} <- @lanes do
      wo = Map.fetch!(orders, lane)
      p = &iri(@sj, &1)

      assert get(g, wo, p.("checkpointOf")) == [Map.fetch!(checkpoints, checkpoint)], lane
      assert one(g, wo, p.("repository")) == "seanchatmangpt/" <> repo
      assert one(g, wo, p.("baseSha")) =~ ~r/\A[0-9a-f]{40}\z/
      assert one(g, wo, p.("subject")) =~ ~r/\S/
      assert strings(g, wo, p.("pathScope")) != []
      assert one(g, wo, p.("postcondition")) =~ ~r/\S/
      assert one(g, wo, p.("evidenceHorizon")) == "EXECUTED_VERIFIED"
      assert one(g, wo, p.("evidenceCeiling")) == "EXECUTED_VERIFIED"
      assert one(g, wo, p.("authorityCeiling")) == "CONSTRUCT"

      assert one(g, wo, p.("consequenceClass")) in ~w(manufacture projection verification actuation replay publication)

      assert one(g, wo, p.("successorPolicy")) == @successor_policy
      assert length(strings(g, wo, p.("exclusion"))) >= 2
      assert one(g, wo, iri(@dct, "title")) =~ ~r/\S/
      assert one(g, wo, iri(@dct, "description")) =~ ~r/\S/
      assert one(g, wo, p.("replayIdentity")) == "semantic-jira:v26.9.23:" <> lane

      assert [cap] = get(g, wo, p.("requiresCapability"))
      assert one(g, cap, p.("capabilityId")) == "construct:#{repo}-lane"

      for {pred, class} <- [
            {"acceptance", "AcceptanceCriterion"},
            {"falsifier", "Falsifier"},
            {"requiresCourt", "Court"},
            {"nextAction", "Action"}
          ] do
        assert [node] = get(g, wo, p.(pred)), "#{lane} #{pred}"
        assert iri(@sj, class) in get(g, node, RDF.iri(@rdf_type))
        assert one(g, node, iri(@dct, "description")) =~ ~r/\S/
      end

      for edge <- get(g, wo, p.("dependsOn")) do
        assert iri(@sj, "DependencyEdge") in get(g, edge, RDF.iri(@rdf_type))
        assert [upstream] = get(g, edge, p.("upstreamWorkOrder"))
        assert iri(@sj, "WorkOrder") in get(g, upstream, RDF.iri(@rdf_type))
        assert one(g, edge, p.("dependencyType")) =~ ~r/\Arequires[A-Z]/
      end
    end

    # V23-W is a reference flow, typed Successor; everything else is required.
    assert get(g, Map.fetch!(orders, "V23-W"), iri(@sj, "boundaryClass")) == [
             iri(@sj, "Successor")
           ]

    # V23-Q waits on the receipts of every required lane.
    upstream =
      g
      |> get(Map.fetch!(orders, "V23-Q"), iri(@sj, "dependsOn"))
      |> Enum.flat_map(&get(g, &1, iri(@sj, "upstreamWorkOrder")))
      |> Enum.map(&one(g, &1, iri(@dct, "identifier")))
      |> Enum.sort()

    assert upstream == Map.keys(@lanes) |> Kernel.--(["V23-Q", "V23-W"]) |> Enum.sort()
  end

  # A court still at the V23-P stub is exactly two code lines (the UNKNOWN
  # line and `exit 75`); a machinery lane's real court may keep a guarded
  # "machinery lands in lane" line (e.g. GC23-10, GC23-11) that exits 75
  # inline. Every such line, stub or guard, must name the lane that owns the
  # script (V23-K: the stub-only reading refused GC23-10's inline guard).
  test "each gate's UNKNOWN stub names a lane whose order's path scope covers that court script" do
    g = graph()
    orders = by_identifier(g, @sj <> "WorkOrder")

    stubs =
      for n <- 0..12, reduce: [] do
        acc ->
          rel = "docs/sjira/v26.9.23/courts/GC23-#{n}.sh"
          body = File.read!(Path.join(@repo, rel))
          pattern = ~r/"UNKNOWN: GC23-#{n} machinery lands in lane (V23-[A-Z])"/

          for [_, lane] <- Regex.scan(pattern, body) do
            scope = strings(g, Map.fetch!(orders, lane), iri(@sj, "pathScope"))
            assert rel in scope or ("xaas:" <> rel) in scope, "#{lane} does not own #{rel}"
          end

          code =
            body
            |> String.split("\n")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))

          case code do
            ["echo " <> message, "exit " <> exit_code] ->
              assert message =~ pattern, "#{rel}: stub message #{message}"
              assert exit_code == Integer.to_string(StopCourt.unknown_exit())
              [n | acc]

            _ ->
              # The machinery lane replaced this stub with its real court.
              acc
          end
      end

    # Courts already real: GC23-0 .. GC23-3 (V23-K), GC23-4 .. GC23-8 (V23-D),
    # GC23-9 (V23-M), GC23-10 (V23-R), GC23-11 (V23-F). Only GC23-12 (V23-H)
    # may still be the machinery-absent stub.
    assert Enum.all?(stubs, &(&1 == 12)), "still stubbed: #{inspect(Enum.sort(stubs))}"
  end

  test "courts/check_scripts.sh accepts the committed court scripts (real sh)" do
    {out, code} =
      System.cmd("sh", [Path.join(@dir, "courts/check_scripts.sh")], stderr_to_stdout: true)

    assert code == 0, out
    assert out =~ "OK: 13 court scripts"
  end

  # ------------------------------------------------------------------ the real stop court

  # GC23-12 is the last gate whose court is still the machinery-absent stub
  # (lane V23-H replaces it after V23-K); GC23-0..GC23-3 run real courts now.
  test "the registry resolves GC-26.9.23: graph, order receipts and court env; required orders are tuple-complete" do
    receipts = tmp_dir("v23_registry")

    {:ok, report} =
      StopCourt.court([
        "--checkpoint",
        "GC-26.9.23",
        "--receipts-dir",
        receipts,
        "--only",
        "GC23-12"
      ])

    assert report.graph == @goal_ttl
    assert report.order_receipts_dir == Path.join(@repo, "receipts/v26.9.23")
    assert report.receipts_dir == receipts
    assert report.court_env["XAAS_DIR"] == @repo

    ggen =
      case System.get_env("GGEN_IGNITER_DIR") do
        dir when is_binary(dir) and dir != "" -> Path.expand(dir)
        _ -> StopCourt.checkpoints()["GC-26.9.23"].ggen_igniter_dir
      end

    assert report.court_env["GGEN_IGNITER_DIR"] == ggen
    assert Enum.map(report.gates, & &1.id) == Enum.map(0..12, &"GC23-#{&1}")
    assert report.stop == false

    gc12 = Path.join(receipts, "GC23-12.json") |> File.read!() |> Jason.decode!()
    assert gc12["standing"]["value"] == "UNKNOWN"
    assert gc12["gate"]["outcome"] == "machinery_absent"
    assert gc12["gate"]["env"]["XAAS_DIR"] == @repo

    # Required orders: every lane except V23-W (under the successor bucket, not the root).
    assert Enum.map(report.orders, & &1.id) |> Enum.sort() ==
             Map.keys(@lanes) |> Kernel.--(["V23-W"]) |> Enum.sort()

    for order <- report.orders do
      assert {:ok, tuple, digest} = order.tuple, "#{order.id}: #{inspect(order.tuple)}"
      assert digest == python_digest(tuple)
      refute order.successor?
    end

    assert StopCourt.checkpoints()["GC-FRI-0800"].graph == "docs/sjira/v26.9.22/friday/goal.ttl"
  end

  # The real GC23-0 court (lane V23-K): prose_spans.py check + ggen_igniter
  # compile_prose --check over the committed projection, under the no-LLM env.
  @tag timeout: 600_000
  test "mix xaas.stop_court --checkpoint GC-26.9.23 --only GC23-0 (real subprocess): ADMITTED ALIVE receipt, STOP=false" do
    receipts = tmp_dir("v23_subprocess")

    {out, code} =
      System.cmd(
        "mix",
        [
          "xaas.stop_court",
          "--checkpoint",
          "GC-26.9.23",
          "--only",
          "GC23-0",
          "--receipts-dir",
          receipts
        ],
        cd: @repo,
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}]
      )

    assert code == 1, out
    assert out =~ "STOP=false"
    assert out =~ ~r/^GC23-0\s+FirstMile\s+ALIVE\s+0\s.*ran/m

    path = Path.join(receipts, "GC23-0.json")
    {vcode, vout} = validate([path, Path.join(receipts, "STOP-GC-26.9.23.json")])
    assert vcode == 0, vout
    assert vout =~ "ADMITTED #{path}"

    receipt = path |> File.read!() |> Jason.decode!()
    assert receipt["identity"]["subject"] == "GC-26.9.23/GC23-0"
    assert receipt["identity"]["subject_sha"] == head(@repo)

    assert receipt["identity"]["graph_hash"] ==
             "sha256:" <>
               Base.encode16(:crypto.hash(:sha256, File.read!(@goal_ttl)), case: :lower)

    assert receipt["standing"]["value"] == "ALIVE"
    assert receipt["gate"]["outcome"] == "passed"
    assert receipt["gate"]["boundary_class"] == "FirstMile"
    assert receipt["gate"]["env"]["XAAS_DIR"] == @repo

    assert [
             %{
               "cmd" => "sh docs/sjira/v26.9.23/courts/GC23-0.sh",
               "exit" => 0,
               "summary" => summary
             }
           ] =
             receipt["replay"]["commands"]

    assert summary ==
             "ALIVE: GC23-0 accepted prose + complete admitted semantic projection " <>
               "(compile_prose --check byte-identical, no LLM)"
  end

  test "an unregistered checkpoint without --graph is refused (exit 2 class)" do
    assert {:error, {:unregistered_checkpoint, "GC-NOPE", missing}} =
             StopCourt.court(["--checkpoint", "GC-NOPE"])

    assert missing == ["--graph", "--receipts-dir", "--order-receipts-dir"]

    err =
      capture_io(:stderr, fn ->
        assert StopCourt.cli(["--checkpoint", "GC-NOPE"]) == 2
      end)

    assert err =~ "unregistered_checkpoint"
  end

  # ------------------------------------------------------------------ first-mile + bootstrap courts (lane V23-K)

  @compiled Path.join(@dir, "compiled")
  @candidates Path.join(@dir, "candidates/prd-ard.ttl")
  @f8 Path.join(@dir, "courts/fixtures/f8")
  @delta_kinds ~w(Postcondition Invariant Falsifier)

  defp ggen_dir do
    case System.get_env("GGEN_IGNITER_DIR") do
      dir when is_binary(dir) and dir != "" -> Path.expand(dir)
      _ -> Path.expand(StopCourt.checkpoints()["GC-26.9.23"].ggen_igniter_dir)
    end
  end

  defp sha256_file(path),
    do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, File.read!(path)), case: :lower)

  # A committed tmp git copy of what the GC23-0..GC23-3 courts read, after
  # `mutate` edits it; the court judges it as XAAS_DIR.
  defp court_repo(mutate) do
    dir = tmp_dir("v23_court_repo")

    for rel <- [
          "docs/sjira/v26.9.23/prd-ard.md",
          "docs/sjira/v26.9.23/goal.ttl",
          "docs/sjira/v26.9.23/candidates",
          "docs/sjira/v26.9.23/compiled",
          "docs/sjira/v26.9.23/courts",
          "docs/sjira/v26.9.23/fleet/universe.json",
          "docs/sjira/v26.9.22/friday/goal.ttl",
          "scripts/sjira/prose_spans.py"
        ] do
      target = Path.join(dir, rel)
      File.mkdir_p!(Path.dirname(target))
      File.cp_r!(Path.join(@repo, rel), target)
    end

    mutate.(dir)
    {_, 0} = System.cmd("git", ["init", "-q", dir])
    {_, 0} = System.cmd("git", ["-C", dir, "add", "-A"])

    {_, 0} =
      System.cmd("git", [
        "-C",
        dir,
        "-c",
        "user.email=court@example.org",
        "-c",
        "user.name=court",
        "commit",
        "-q",
        "-m",
        "court fixture"
      ])

    {top, 0} = System.cmd("git", ["-C", dir, "rev-parse", "--show-toplevel"])
    String.trim(top)
  end

  # The court as the stop court runs it: /bin/sh from the xaas root, MIX_ENV unset.
  defp run_court(repo, gate, ggen) do
    System.cmd("sh", [Path.join(repo, "docs/sjira/v26.9.23/courts/#{gate}.sh")],
      cd: repo,
      stderr_to_stdout: true,
      env: [{"XAAS_DIR", repo}, {"GGEN_IGNITER_DIR", ggen}, {"MIX_ENV", nil}]
    )
  end

  defp mutate_file!(path, fun) do
    before = File.read!(path)
    after_ = fun.(before)
    assert after_ != before, "mutation of #{path} changed nothing"
    File.write!(path, after_)
  end

  test "compiled/ is the admitted projection of the committed prose, candidates and goal; each order sits under the gate requiring its proposition" do
    props_ttl = File.read!(Path.join(@compiled, "propositions.ttl"))
    orders_ttl = File.read!(Path.join(@compiled, "orders.ttl"))

    for ttl <- [props_ttl, orders_ttl] do
      assert ttl =~ "\n# source: docs/sjira/v26.9.23/prd-ard.md sha256:#{@prose_sha256}\n"

      assert ttl =~
               "\n# candidates: #{sha256_file(@candidates)}; goal: #{sha256_file(@goal_ttl)}\n"
    end

    props = RDF.Turtle.read_string!(props_ttl)
    orders = RDF.Turtle.read_string!(orders_ttl)
    candidates = RDF.Turtle.read_file!(@candidates)
    g = graph()

    admitted = MapSet.new(typed(props, @sj <> "Proposition"))
    assert admitted == MapSet.new(typed(candidates, @sj <> "Proposition"))

    for p <- admitted do
      assert get(props, p, iri(@sj, "candidateStanding")) == []
      assert [_digest] = get(props, p, iri(@sj, "admissionDigest"))
    end

    root = iri(@v23, "GC-26.9.23")

    gates =
      for s <- typed(g, @sj <> "GoalCheckpoint"),
          root in get(g, s, iri(@sj, "checkpointOf")),
          into: MapSet.new([root]),
          do: s

    assert MapSet.size(gates) == 14

    required_delta =
      for p <- admitted,
          one(props, p, iri(@sj, "propositionKind")) in @delta_kinds,
          get(props, p, iri(@sj, "requiredBy")) != [],
          into: MapSet.new(),
          do: p

    placed =
      for wo <- typed(orders, @sj <> "WorkOrder") do
        proposition = RDF.iri(one(orders, wo, iri(@sj, "subject")))
        assert proposition in required_delta, "#{wo}: #{proposition}"
        assert [gate] = get(props, proposition, iri(@sj, "requiredBy"))
        assert get(orders, wo, iri(@sj, "checkpointOf")) == [gate], "#{wo}"
        assert gate in gates
        proposition
      end

    assert length(placed) == MapSet.size(required_delta)
    assert MapSet.new(placed) == required_delta
  end

  test "F8 fixture: the successor root pins the discovered prose; both extractions bind the same proposition, one to GC23-8 and one to GC24-F8" do
    discovered = Path.join(@f8, "discovered.md")
    successor = RDF.Turtle.read_file!(Path.join(@f8, "successor-goal.ttl"))
    bucket = iri(@v23, "GC-26.9.24")
    fixture_gate = iri(@v23, "GC24-F8")

    assert one(successor, bucket, iri(@sj, "sourceSha256")) == sha256_file(discovered)
    assert get(successor, bucket, iri(@sj, "successorOf")) == [iri(@v23, "GC-26.9.23")]
    assert get(successor, fixture_gate, iri(@sj, "checkpointOf")) == [bucket]
    # the fixture gate never enters the governing graph
    refute RDF.Graph.describes?(graph(), fixture_gate)

    refute one(graph(), iri(@v23, "GC-26.9.23"), iri(@sj, "sourceSha256")) ==
             sha256_file(discovered)

    emitted =
      for x <- ~w(attack routed) do
        out = Path.join(tmp_dir("v23_f8_#{x}"), "#{x}.ttl")

        {log, 0} =
          System.cmd(
            "python3",
            [
              Path.join(@repo, "scripts/sjira/prose_spans.py"),
              "emit",
              "--source",
              "docs/sjira/v26.9.23/courts/fixtures/f8/discovered.md",
              "--extract",
              Path.join(@f8, "extract-#{x}.json"),
              "--out",
              out,
              "--source-path",
              "docs/sjira/v26.9.23/courts/fixtures/f8/discovered.md",
              "--extracted-by",
              "fixture:GC23-2-F8"
            ],
            cd: @repo,
            stderr_to_stdout: true
          )

        assert log =~ "EMIT: 1 candidates"
        candidate = RDF.Turtle.read_file!(out)
        assert [p] = typed(candidate, @sj <> "Proposition")
        {p, get(candidate, p, iri(@sj, "requiredBy"))}
      end

    assert [{p, [attack]}, {p, [routed]}] = emitted
    assert attack == iri(@v23, "GC23-8")
    assert routed == fixture_gate
  end

  test "GC23-0..GC23-3 courts map an absent ggen_igniter machinery to UNKNOWN (exit 75)" do
    empty = tmp_dir("v23_no_ggen")

    for {gate, lane} <- [
          {"GC23-0", "V23-C"},
          {"GC23-1", "V23-B"},
          {"GC23-2", "V23-C"},
          {"GC23-3", "V23-C"}
        ] do
      {out, code} = run_court(@repo, gate, empty)
      assert code == StopCourt.unknown_exit(), "#{gate}: #{out}"
      assert out =~ ~r/^UNKNOWN: #{gate} .*\(lane #{lane}\) absent/m
    end
  end

  @tag timeout: 600_000
  test "GC23-0 (real sh + ggen_igniter compile_prose --check) refuses a hand-edited compiled/orders.ttl" do
    repo =
      court_repo(fn dir ->
        mutate_file!(Path.join(dir, "docs/sjira/v26.9.23/compiled/orders.ttl"), fn bytes ->
          bytes <> "<urn:x:hand> <urn:x:edited> \"not manufactured\" .\n"
        end)
      end)

    {out, code} = run_court(repo, "GC23-0", ggen_dir())
    assert code == 1, out
    assert out =~ ~r/^REFUSED\(output_drift\) .*compiled\/orders\.ttl: /m
    assert out =~ "REFUSED: GC23-0 compile_prose --check exited 1"
    refute out =~ "ALIVE: GC23-0"
  end

  @tag timeout: 600_000
  test "GC23-3 (real sh + ggen_igniter --admit-goal) refuses a goal.ttl whose lane order lost sj:postcondition (F1)" do
    repo =
      court_repo(fn dir ->
        mutate_file!(Path.join(dir, "docs/sjira/v26.9.23/goal.ttl"), fn bytes ->
          String.replace(
            bytes,
            ~r/^    sj:postcondition "One reference KNOWN WorkOrder[^\n]*\n/m,
            ""
          )
        end)
      end)

    {out, code} = run_court(repo, "GC23-3", ggen_dir())
    assert code == 1, out

    assert out =~
             ~r/^REFUSED\(goal_inadmissible\) #{Regex.escape(@v23)}WO-V23-D: .*postcondition/m

    assert out =~
             "REFUSED: GC23-3 docs/sjira/v26.9.23/goal.ttl is not admitted under the pack shapes"

    refute out =~ "ALIVE: GC23-3"
  end

  # ------------------------------------------------------------------ fixture courts over the real stop.rq

  @q3 ~s(""")

  defp fixture_repo do
    dir = tmp_dir("v23_fixture")
    File.mkdir_p!(Path.join(dir, "goal"))
    File.cp!(@stop_rq, Path.join(dir, "goal/stop.rq"))
    {_, 0} = System.cmd("git", ["init", "-q", dir])

    {_, 0} =
      System.cmd("git", [
        "-C",
        dir,
        "-c",
        "user.email=court@example.org",
        "-c",
        "user.name=court",
        "commit",
        "-q",
        "--allow-empty",
        "-m",
        "fixture"
      ])

    # The court judges the git toplevel (on macOS /var is /private/var).
    {top, 0} = System.cmd("git", ["-C", dir, "rev-parse", "--show-toplevel"])
    String.trim(top)
  end

  # Root GC-26.9.23 with the REAL stop.rq, gates with the given commands, one
  # tuple-complete order under gate GA (transitive), one under the successor bucket.
  defp write_fixture(repo, gates) do
    stop = @stop_rq |> File.read!() |> String.trim()

    gate_ttl =
      Enum.map_join(gates, "\n", fn {id, command} ->
        """
        v23:#{id} a sj:GoalCheckpoint ;
            dcterms:identifier "#{id}" ;
            rdfs:label "#{id} fixture gate" ;
            sj:checkpointOf v23:GC-26.9.23 ;
            sj:boundaryClass sj:Core ;
            sj:courtCommand #{@q3}#{command}#{@q3} .
        """
      end)

    File.write!(Path.join(repo, "goal/goal.ttl"), """
    @prefix sj: <https://ggen-igniter.dev/ontology/semantic-jira#> .
    @prefix v23: <https://ggen-igniter.dev/sjira/v26.9.23#> .
    @prefix dcterms: <http://purl.org/dc/terms/> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

    v23:GC-26.9.23 a sj:GoalCheckpoint ;
        dcterms:identifier "GC-26.9.23" ;
        rdfs:label "fixture root" ;
        sj:stopQuery #{@q3}#{stop}#{@q3} .
    v23:GC-26.9.24 a sj:GoalCheckpoint ;
        dcterms:identifier "GC-26.9.24" ;
        rdfs:label "fixture successor" ;
        sj:successorOf v23:GC-26.9.23 .

    #{gate_ttl}

    v23:cap a sj:Capability ; sj:capabilityId "construct:xaas-lane" .
    v23:WO-A a sj:WorkOrder ;
        dcterms:identifier "WO-A" ;
        sj:checkpointOf v23:GA ;
        sj:subject "fixture:transitive-order" ;
        sj:postcondition "the fixture postcondition holds" ;
        sj:requiresCapability v23:cap ;
        sj:evidenceCeiling "EXECUTED_VERIFIED" ;
        sj:authorityCeiling "CONSTRUCT" ;
        sj:consequenceClass "manufacture" ;
        sj:exclusion "no LLM on the KNOWN path" .
    v23:WO-S a sj:WorkOrder ;
        dcterms:identifier "WO-S" ;
        sj:checkpointOf v23:GC-26.9.24 ;
        sj:subject "fixture:successor-order" ;
        sj:postcondition "never required by GC-26.9.23" ;
        sj:requiresCapability v23:cap ;
        sj:evidenceCeiling "EXECUTED_VERIFIED" ;
        sj:authorityCeiling "CONSTRUCT" ;
        sj:consequenceClass "manufacture" ;
        sj:exclusion "no LLM on the KNOWN path" .
    """)
  end

  @wo_a_tuple %{
    "subject" => "fixture:transitive-order",
    "postcondition" => "the fixture postcondition holds",
    "capability" => "construct:xaas-lane",
    "evidence_ceiling" => "EXECUTED_VERIFIED",
    "authority_ceiling" => "CONSTRUCT",
    "consequence_class" => "manufacture",
    "exclusions" => ["no LLM on the KNOWN path"]
  }

  defp fixture_args(repo, more) do
    [
      "--checkpoint",
      "GC-26.9.23",
      "--repo",
      repo,
      "--graph",
      Path.join(repo, "goal/goal.ttl"),
      "--receipts-dir",
      Path.join(repo, "gate-receipts"),
      "--order-receipts-dir",
      Path.join(repo, "order-receipts")
    ] ++ more
  end

  defp fixture_court(repo, more \\ []) do
    code = make_ref()

    out =
      capture_io(fn -> send(self(), {code, StopCourt.cli(fixture_args(repo, more))}) end)

    assert_received {^code, exit_code}
    {exit_code, out}
  end

  defp write_order_receipt(repo, id, digest, standing) do
    File.mkdir_p!(Path.join(repo, "order-receipts"))
    sha = head(repo)
    path = Path.join(repo, "order-receipts/#{id}.json")

    File.write!(
      path,
      Jason.encode!(%{
        "identity" => %{
          "subject" => id,
          "repo" => repo,
          "subject_sha" => sha,
          "base_sha" => sha,
          "tuple_digest" => digest
        },
        "authority" => %{"ceiling" => "CONSTRUCT", "grant" => "NONE", "actor" => "fixture"},
        "consequence" => %{"commits" => [], "files_changed" => [], "remote_effects" => []},
        "replay" => %{"commands" => [%{"cmd" => "true", "cwd" => repo, "exit" => 0}]},
        "standing" => %{"value" => standing, "derived_from" => "fixture command exit 0"}
      })
    )

    path
  end

  test "court exit-code contract: 0 passed/ALIVE, 75 machinery_absent/UNKNOWN, other court_failed/UNKNOWN" do
    repo = fixture_repo()
    write_fixture(repo, [{"GA", "true"}, {"GB", "exit 75"}, {"GC", "exit 3"}])

    {code, out} = fixture_court(repo)
    assert code == 1
    assert out =~ ~r/^GA\s+Core\s+ALIVE\s+0\s/m
    assert out =~ ~r/^GB\s+Core\s+UNKNOWN\s+75\s/m
    assert out =~ ~r/^GC\s+Core\s+UNKNOWN\s+3\s/m

    outcomes =
      Map.new(~w(GA GB GC), fn id ->
        receipt = Path.join(repo, "gate-receipts/#{id}.json")
        assert {0, _} = validate([receipt])
        {id, receipt |> File.read!() |> Jason.decode!() |> get_in(["gate", "outcome"])}
      end)

    assert outcomes == %{"GA" => "passed", "GB" => "machinery_absent", "GC" => "court_failed"}
  end

  test "court env: XAAS_DIR is the repository under judgement, GGEN_IGNITER_DIR follows --ggen-igniter-dir" do
    repo = fixture_repo()
    ggen = tmp_dir("v23_ggen_igniter")
    {_, 0} = System.cmd("git", ["init", "-q", ggen])

    {_, 0} =
      System.cmd("git", [
        "-C",
        ggen,
        "-c",
        "user.email=court@example.org",
        "-c",
        "user.name=court",
        "commit",
        "-q",
        "--allow-empty",
        "-m",
        "ggen fixture"
      ])

    write_fixture(repo, [
      {"GA", ~s(test "$XAAS_DIR" = "#{repo}" && test "$GGEN_IGNITER_DIR" = "#{ggen}" && true)}
    ])

    {_code, out} = fixture_court(repo, ["--ggen-igniter-dir", ggen])
    assert out =~ ~r/^GA\s+Core\s+ALIVE\s+0\s/m
    assert out =~ "court env GGEN_IGNITER_DIR=#{ggen} XAAS_DIR=#{repo}"

    receipt = Path.join(repo, "gate-receipts/GA.json") |> File.read!() |> Jason.decode!()
    assert receipt["gate"]["env"] == %{"XAAS_DIR" => repo, "GGEN_IGNITER_DIR" => ggen}
    assert receipt["gate"]["ggen_igniter_sha"] == head(ggen)

    # A different GGEN_IGNITER_DIR makes the same court fail: the env is really exported.
    {_code, out} = fixture_court(repo, ["--ggen-igniter-dir", repo])
    assert out =~ ~r/^GA\s+Core\s+UNKNOWN\s+1\s/m
  end

  test "real stop.rq: a WorkOrder under a gate (checkpointOf+) holds STOP open until its bound receipt; a successor-bucket order never does" do
    repo = fixture_repo()
    write_fixture(repo, [{"GA", "true"}])
    digest = python_digest(@wo_a_tuple)

    {code, out} = fixture_court(repo)
    assert code == 1, "WO-A (under gate GA) has no receipt yet"
    assert out =~ "order WO-A standing=NONE receipt=MISSING digest=#{digest}"
    refute out =~ "order WO-S"

    write_order_receipt(repo, "WO-A", "sha256:" <> String.duplicate("0", 64), "ALIVE")
    {code, out} = fixture_court(repo)
    assert code == 1
    assert out =~ "unlinked=:tuple_digest_mismatch"

    write_order_receipt(repo, "WO-A", digest, "UNKNOWN")
    assert {1, _} = fixture_court(repo)

    write_order_receipt(repo, "WO-A", digest, "ALIVE")
    {code, out} = fixture_court(repo)
    assert code == 0, out
    assert out =~ "order WO-A standing=ALIVE receipt=ADMITTED digest=#{digest}"
    assert out =~ "STOP=true"
  end

  unless @rdflib do
    @tag skip: "needs python3 rdflib for the independent ASK"
  end

  test "the oxigraph SELECT-existence answer equals rdflib's native ASK on the real stop.rq (transitive orders)" do
    query = File.read!(@stop_rq)
    {:ok, select} = StopCourt.ask_as_select(query)
    t = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

    base = """
    <urn:x:root> <#{t}> <#{@sj}GoalCheckpoint> .
    <urn:x:root> <http://purl.org/dc/terms/identifier> "GC-26.9.23" .
    <urn:x:g1> <#{t}> <#{@sj}GoalCheckpoint> .
    <urn:x:g1> <#{@sj}checkpointOf> <urn:x:root> .
    <urn:x:g1> <#{@sj}receipt> <urn:x:r1> .
    <urn:x:r1> <#{t}> <#{@sj}Receipt> .
    <urn:x:r1> <#{@sj}standing> "ALIVE" .
    """

    order = """
    <urn:x:wo> <#{t}> <#{@sj}WorkOrder> .
    <urn:x:wo> <#{@sj}checkpointOf> <urn:x:g1> .
    """

    order_receipt = fn standing ->
      """
      <urn:x:wo> <#{@sj}receipt> <urn:x:r2> .
      <urn:x:r2> <#{t}> <#{@sj}Receipt> .
      <urn:x:r2> <#{@sj}standing> "#{standing}" .
      """
    end

    successor = "<urn:x:wo> <#{@sj}boundaryClass> <#{@sj}Successor> .\n"

    for {nt, expected} <- [
          {base, true},
          {base <> order, false},
          {base <> order <> order_receipt.("UNKNOWN"), false},
          {base <> order <> order_receipt.("BLOCKED:operator"), true},
          {base <> order <> order_receipt.("ALIVE"), true},
          {base <> order <> successor, true}
        ] do
      {:ok, rows} = GgenIgniter.Native.GraphNif.query_turtle(nt, select)

      {py, 0} =
        System.cmd("python3", [
          "-c",
          "import rdflib,sys; g=rdflib.Graph(); g.parse(data=sys.argv[1], format='nt'); print(g.query(sys.argv[2]).askAnswer)",
          nt,
          query
        ])

      assert rows != [] == expected, nt
      assert String.trim(py) == to_string(expected) |> String.capitalize(), nt
    end
  end

  # ------------------------------------------------------------------ order receipts from both critical-path repos (lane V23-L)

  # A real git checkout standing in for GGEN_IGNITER_DIR (its toplevel path).
  defp ggen_checkout do
    dir = tmp_dir("v23l_ggen_igniter")
    {_, 0} = System.cmd("git", ["init", "-q", dir])
    commit!(dir, "ggen fixture")
    {top, 0} = System.cmd("git", ["-C", dir, "rev-parse", "--show-toplevel"])
    String.trim(top)
  end

  defp commit!(repo, message) do
    {_, 0} = System.cmd("git", ["-C", repo, "add", "-A"])

    {_, 0} =
      System.cmd("git", [
        "-C",
        repo,
        "-c",
        "user.email=court@example.org",
        "-c",
        "user.name=court",
        "commit",
        "-q",
        "--allow-empty",
        "-m",
        message
      ])

    head(repo)
  end

  # The registry defaults for GC-26.9.23: no --order-receipts-dir, so the
  # order receipts are read from <repo>/receipts/v26.9.23, then
  # <ggen>/receipts/v26.9.23.
  defp registry_args(repo, ggen, more) do
    [
      "--checkpoint",
      "GC-26.9.23",
      "--repo",
      repo,
      "--graph",
      Path.join(repo, "goal/goal.ttl"),
      "--receipts-dir",
      Path.join(repo, "gate-receipts"),
      "--ggen-igniter-dir",
      ggen
    ] ++ more
  end

  defp registry_court(repo, ggen, more \\ []) do
    code = make_ref()

    out =
      capture_io(fn -> send(self(), {code, StopCourt.cli(registry_args(repo, ggen, more))}) end)

    assert_received {^code, exit_code}
    {exit_code, out}
  end

  # An R-schema order receipt in `dir`, identity bound to the HEAD of the
  # repository that holds `dir`; `note` varies the bytes.
  defp put_order_receipt(dir, id, digest, standing, note) do
    File.mkdir_p!(dir)
    {top, 0} = System.cmd("git", ["-C", dir, "rev-parse", "--show-toplevel"])
    put_subject_receipt(dir, String.trim(top), id, digest, standing, note)
  end

  # The same receipt stored in `dir` (any directory: a checkout, or not) with
  # its identity bound to the HEAD of the SHA-1 checkout `top` (the R schema
  # requires a 40-hex subject_sha; the storing repository is provenance only).
  defp put_subject_receipt(dir, top, id, digest, standing, note) do
    File.mkdir_p!(dir)
    sha = head(top)
    path = Path.join(dir, "#{id}.json")

    File.write!(
      path,
      Jason.encode!(%{
        "identity" => %{
          "subject" => id,
          "repo" => top,
          "subject_sha" => sha,
          "base_sha" => sha,
          "tuple_digest" => digest
        },
        "authority" => %{"ceiling" => "CONSTRUCT", "grant" => "NONE", "actor" => "fixture"},
        "consequence" => %{"commits" => [], "files_changed" => [], "remote_effects" => []},
        "replay" => %{"commands" => [%{"cmd" => "true", "cwd" => top, "exit" => 0}]},
        "standing" => %{"value" => standing, "derived_from" => note}
      })
    )

    path
  end

  # The STOP receipt, re-validated by an independent validator run, keyed by order.
  defp stop_orders(repo) do
    path = Path.join(repo, "gate-receipts/STOP-GC-26.9.23.json")
    {vcode, vout} = validate([path])
    assert vcode == 0, vout
    assert vout =~ "ADMITTED #{path}"
    receipt = path |> File.read!() |> Jason.decode!()
    {receipt, Map.new(receipt["stop"]["orders"], &{&1["order"], &1})}
  end

  defp sha256_of(path),
    do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, File.read!(path)), case: :lower)

  test "GC-26.9.23 registry: order receipts from <repo>/receipts/v26.9.23, then GGEN_IGNITER_DIR/receipts/v26.9.23 (--ggen-igniter-dir precedence)" do
    assert StopCourt.checkpoints()["GC-26.9.23"].order_receipts_dirs == [
             {:repo, "receipts/v26.9.23"},
             {:ggen_igniter, "receipts/v26.9.23"}
           ]

    repo = fixture_repo()
    write_fixture(repo, [{"GA", "true"}])
    ggen = ggen_checkout()
    File.mkdir_p!(Path.join(ggen, "receipts/v26.9.23"))

    {:ok, report} = StopCourt.court(registry_args(repo, ggen, []))

    assert Enum.map(report.order_receipts_dirs, &{&1.origin, &1.dir, &1.repo, &1.head}) == [
             {"repo", Path.join(repo, "receipts/v26.9.23"), nil, nil},
             {"ggen_igniter", Path.join(ggen, "receipts/v26.9.23"), ggen, head(ggen)}
           ]

    assert report.order_receipts_dir == Path.join(repo, "receipts/v26.9.23")
    assert report.court_env["GGEN_IGNITER_DIR"] == ggen

    {stop, _orders} = stop_orders(repo)

    assert stop["stop"]["order_receipt_dirs"] == [
             %{
               "dir" => Path.join(repo, "receipts/v26.9.23"),
               "origin" => "repo",
               "repo" => nil,
               "repo_head" => nil,
               "repo_head_why" => "directory absent"
             },
             %{
               "dir" => Path.join(ggen, "receipts/v26.9.23"),
               "origin" => "ggen_igniter",
               "repo" => ggen,
               "repo_head" => head(ggen),
               "repo_head_why" => nil
             }
           ]
  end

  test "an order whose receipt lives only in the second dir (GGEN_IGNITER_DIR) links ALIVE; the STOP receipt records that dir and repo HEAD" do
    repo = fixture_repo()
    write_fixture(repo, [{"GA", "true"}])
    ggen = ggen_checkout()
    digest = python_digest(@wo_a_tuple)
    dir = Path.join(ggen, "receipts/v26.9.23")

    path = put_order_receipt(dir, "WO-A", digest, "ALIVE", "fixture command exit 0")
    receipt_head = commit!(ggen, "WO-A receipt")
    refute File.exists?(Path.join(repo, "receipts/v26.9.23/WO-A.json"))

    {code, out} = registry_court(repo, ggen)
    assert code == 0, out
    assert out =~ "order WO-A standing=ALIVE receipt=ADMITTED digest=#{digest}"
    assert out =~ "from=ggen_igniter:#{dir}@#{receipt_head}"
    assert out =~ "order receipts ggen_igniter #{dir} (#{ggen} @ #{receipt_head})"
    assert out =~ "STOP=true"

    {stop, orders} = stop_orders(repo)
    assert stop["standing"]["value"] == "ALIVE"

    assert orders["WO-A"] == %{
             "order" => "WO-A",
             "tuple_digest" => digest,
             "verdict" => "ADMITTED",
             "linked" => true,
             "standing" => "ALIVE",
             "why_unlinked" => nil,
             "found_in" => [path],
             "receipt" => path,
             "receipt_sha256" => sha256_of(path),
             "dir" => dir,
             "origin" => "ggen_igniter",
             "repo" => ggen,
             "repo_head" => receipt_head,
             "repo_head_why" => nil,
             "committed_at_head" => true,
             "committed_at_head_why" => nil
           }

    # The same dir, bytes no longer the blob at HEAD: still linked, recorded uncommitted.
    put_order_receipt(dir, "WO-A", digest, "ALIVE", "fixture command exit 0 (edited)")
    assert {0, _} = registry_court(repo, ggen)
    {_stop, orders} = stop_orders(repo)
    assert orders["WO-A"]["linked"] == true
    assert orders["WO-A"]["committed_at_head"] == false
    assert orders["WO-A"]["committed_at_head_why"] == "receipt bytes differ from the blob at HEAD"
  end

  test "an order receipt missing from every dir stays MISSING (STOP=false)" do
    repo = fixture_repo()
    write_fixture(repo, [{"GA", "true"}])
    ggen = ggen_checkout()
    File.mkdir_p!(Path.join(repo, "receipts/v26.9.23"))
    File.mkdir_p!(Path.join(ggen, "receipts/v26.9.23"))
    digest = python_digest(@wo_a_tuple)

    {code, out} = registry_court(repo, ggen)
    assert code == 1
    assert out =~ "order WO-A standing=NONE receipt=MISSING digest=#{digest} unlinked=:missing\n"
    assert out =~ "STOP=false"

    {stop, orders} = stop_orders(repo)
    assert stop["standing"]["value"] == "UNKNOWN"
    assert orders["WO-A"]["verdict"] == "MISSING"
    assert orders["WO-A"]["linked"] == false
    assert orders["WO-A"]["found_in"] == []
    assert orders["WO-A"]["dir"] == nil
    assert orders["WO-A"]["repo_head"] == nil
  end

  test "different receipts for one order in both dirs: REFUSED(duplicate_order_receipt), never a silent pick" do
    repo = fixture_repo()
    write_fixture(repo, [{"GA", "true"}])
    ggen = ggen_checkout()
    digest = python_digest(@wo_a_tuple)
    xaas_dir = Path.join(repo, "receipts/v26.9.23")
    ggen_dir = Path.join(ggen, "receipts/v26.9.23")

    a = put_order_receipt(xaas_dir, "WO-A", digest, "ALIVE", "the xaas copy")
    b = put_order_receipt(ggen_dir, "WO-A", digest, "ALIVE", "the ggen_igniter copy")

    # Each copy alone is ADMITTED and bound to the digest: either would link.
    {vcode, vout} = validate([a, b])
    assert vcode == 0, vout

    {code, out} = registry_court(repo, ggen)
    assert code == 1, out

    assert out =~
             "order WO-A standing=NONE receipt=REFUSED digest=#{digest}" <>
               " unlinked=#{inspect({:duplicate_order_receipt, [a, b]})}"

    assert out =~ "STOP=false"
    refute out =~ "from="

    {stop, orders} = stop_orders(repo)
    assert stop["standing"]["value"] == "UNKNOWN"
    wo = orders["WO-A"]
    assert wo["refusal"] == "REFUSED(duplicate_order_receipt)"
    assert wo["broken_term"] == "R_missing_identity"
    assert wo["verdict"] == "REFUSED"
    assert wo["linked"] == false
    assert wo["found_in"] == [a, b]
    assert wo["receipt"] == nil
    assert wo["dir"] == nil

    # Same bytes in both dirs is one receipt, judged from the first dir.
    File.cp!(b, a)
    {code, out} = registry_court(repo, ggen)
    assert code == 0, out
    {_stop, orders} = stop_orders(repo)
    assert orders["WO-A"]["dir"] == xaas_dir
    assert orders["WO-A"]["origin"] == "repo"
    assert orders["WO-A"]["found_in"] == [a, b]
    refute Map.has_key?(orders["WO-A"], "refusal")

    # Only the second dir left: it links from there.
    File.rm!(a)
    {code, _out} = registry_court(repo, ggen)
    assert code == 0
    {_stop, orders} = stop_orders(repo)
    assert orders["WO-A"]["dir"] == ggen_dir
    assert orders["WO-A"]["found_in"] == [b]
  end

  test "--order-receipts-dir is repeatable and replaces the registry list (GGEN_IGNITER_DIR is then not read)" do
    repo = fixture_repo()
    write_fixture(repo, [{"GA", "true"}])
    ggen = ggen_checkout()
    digest = python_digest(@wo_a_tuple)
    first = Path.join(repo, "first")
    second = Path.join(repo, "second")

    put_order_receipt(Path.join(ggen, "receipts/v26.9.23"), "WO-A", digest, "ALIVE", "ggen copy")
    more = ["--order-receipts-dir", first, "--order-receipts-dir", second]

    {code, out} = registry_court(repo, ggen, more)
    assert code == 1
    assert out =~ "order WO-A standing=NONE receipt=MISSING digest=#{digest}"
    assert out =~ "order receipts option #{first} "
    assert out =~ "order receipts option #{second} "
    refute out =~ "order receipts ggen_igniter"

    # Only in the first of the repeated dirs: every given dir is read, in
    # order (the option is not collapsed to its last value).
    path = put_order_receipt(first, "WO-A", digest, "ALIVE", "first copy")
    {code, out} = registry_court(repo, ggen, more)
    assert code == 0, out
    assert out =~ "from=option:#{first}@#{head(repo)}"
    {_stop, orders} = stop_orders(repo)
    assert orders["WO-A"]["found_in"] == [path]
    assert orders["WO-A"]["committed_at_head"] == false
    assert orders["WO-A"]["committed_at_head_why"] == "HEAD has no blob at this path"

    # Only in the second: linked from there.
    File.rm!(path)
    path = put_order_receipt(second, "WO-A", digest, "ALIVE", "second copy")
    {code, out} = registry_court(repo, ggen, more)
    assert code == 0, out
    assert out =~ "from=option:#{second}@#{head(repo)}"
    {_stop, orders} = stop_orders(repo)
    assert orders["WO-A"]["found_in"] == [path]
    assert orders["WO-A"]["repo"] == repo

    {:ok, report} = StopCourt.court(registry_args(repo, ggen, more))

    assert Enum.map(report.order_receipts_dirs, &{&1.origin, &1.dir}) == [
             {"option", first},
             {"option", second}
           ]
  end

  test "committed_at_head is typed: false with the reason, or null with the git failure (never folded into false)" do
    repo = fixture_repo()
    write_fixture(repo, [{"GA", "true"}])
    ggen = ggen_checkout()
    digest = python_digest(@wo_a_tuple)

    # A git checkout whose HEAD tree object is gone: HEAD resolves, the tree
    # cannot be read (`rev-parse --verify --quiet HEAD:./x` would exit 1 here,
    # the same as for a missing path).
    broken = ggen_checkout()
    broken_dir = Path.join(broken, "receipts")
    committed = put_order_receipt(broken_dir, "WO-A", digest, "ALIVE", "committed copy")
    commit!(broken, "WO-A receipt")
    {tree, 0} = System.cmd("git", ["-C", broken, "rev-parse", "HEAD^{tree}"])
    <<fan::binary-size(2), rest::binary>> = String.trim(tree)
    File.rm!(Path.join([broken, ".git", "objects", fan, rest]))

    # A directory outside any git checkout.
    plain = tmp_dir("v23l_plain")

    assert {_, code} =
             System.cmd("git", ["-C", plain, "rev-parse", "--show-toplevel"],
               stderr_to_stdout: true
             )

    assert code != 0
    File.cp!(committed, Path.join(plain, "WO-A.json"))

    {code, out} = registry_court(repo, ggen, ["--order-receipts-dir", plain])
    assert code == 0, out
    assert out =~ "order receipts option #{plain} (no git checkout)"
    {_stop, orders} = stop_orders(repo)
    assert orders["WO-A"]["linked"] == true
    assert orders["WO-A"]["repo"] == nil
    assert orders["WO-A"]["committed_at_head"] == false
    assert orders["WO-A"]["committed_at_head_why"] == "no git checkout holds the receipt dir"

    {code, out} = registry_court(repo, ggen, ["--order-receipts-dir", broken_dir])
    assert code == 0, out
    {_stop, orders} = stop_orders(repo)
    assert orders["WO-A"]["linked"] == true
    assert orders["WO-A"]["repo"] == broken
    assert orders["WO-A"]["committed_at_head"] == nil
    assert orders["WO-A"]["committed_at_head_why"] =~ ":git_failed"
    assert orders["WO-A"]["committed_at_head_why"] =~ "ls-tree"
  end

  test "the receipt-dir probe is typed: unborn HEAD, a checkout git cannot read, and SHA-256 HEADs are never 'no git checkout'" do
    repo = fixture_repo()
    write_fixture(repo, [{"GA", "true"}])
    ggen = ggen_checkout()
    digest = python_digest(@wo_a_tuple)

    # Unborn: a checkout whose branch has no commit. Provably not committed at
    # HEAD (false), and the reason names the unborn branch.
    unborn = tmp_dir("v23l_unborn")
    {_, 0} = System.cmd("git", ["init", "-q", "-b", "main", unborn])
    {top, 0} = System.cmd("git", ["-C", unborn, "rev-parse", "--show-toplevel"])
    unborn = String.trim(top)
    unborn_dir = Path.join(unborn, "receipts")
    put_subject_receipt(unborn_dir, repo, "WO-A", digest, "ALIVE", "unborn copy")
    why = "HEAD refs/heads/main has no commit (unborn branch)"

    {code, out} = registry_court(repo, ggen, ["--order-receipts-dir", unborn_dir])
    assert code == 0, out
    assert out =~ "order receipts option #{unborn_dir} (#{unborn} @ unborn: #{why})"
    assert out =~ "from=option:#{unborn_dir}@-"
    {stop, orders} = stop_orders(repo)

    assert [%{"repo" => ^unborn, "repo_head" => nil, "repo_head_why" => ^why}] =
             stop["stop"]["order_receipt_dirs"]

    assert %{
             "linked" => true,
             "repo" => ^unborn,
             "repo_head" => nil,
             "repo_head_why" => ^why,
             "committed_at_head" => false,
             "committed_at_head_why" => ^why
           } = orders["WO-A"]

    # A checkout git refuses to read (corrupt .git/HEAD: git no longer
    # recognises it, although the `.git` is there) and a directory inside
    # `.git` (not a work tree): the git failure is recorded, committed_at_head
    # is null, never "no git checkout" / false.
    corrupt = ggen_checkout()
    corrupt_dir = Path.join(corrupt, "receipts")
    put_subject_receipt(corrupt_dir, repo, "WO-A", digest, "ALIVE", "corrupt copy")
    commit!(corrupt, "WO-A receipt")
    File.write!(Path.join(corrupt, ".git/HEAD"), "not a ref\n")
    inside_git = Path.join(ggen, ".git/receipts")
    put_subject_receipt(inside_git, repo, "WO-A", digest, "ALIVE", "inside .git copy")

    for {dir, failure} <- [
          {corrupt_dir,
           ~r/\{:git_failed, \["rev-parse", "--show-toplevel"\], 128, "fatal: |:toplevel_mismatch/},
          {inside_git, ~r/\{:git_failed, \["rev-parse", "--show-toplevel"\], 128, "fatal: /}
        ] do
      {code, out} = registry_court(repo, ggen, ["--order-receipts-dir", dir])
      assert code == 0, out
      assert out =~ "order receipts option #{dir} ("
      assert out =~ " git failed: "
      refute out =~ "no git checkout"
      {stop, orders} = stop_orders(repo)
      [probe] = stop["stop"]["order_receipt_dirs"]
      assert probe["repo_head"] == nil
      assert probe["repo_head_why"] =~ failure
      wo = orders["WO-A"]
      assert wo["linked"] == true
      assert wo["repo_head"] == nil
      assert wo["committed_at_head"] == nil
      assert wo["committed_at_head_why"] == probe["repo_head_why"]
    end

    # SHA-256 object format: a 64-hex HEAD is a HEAD, and the committed blob
    # compares equal (hash-object and ls-tree speak the repository's format).
    s256 = tmp_dir("v23l_sha256")
    {_, 0} = System.cmd("git", ["init", "-q", "--object-format=sha256", s256])
    {top, 0} = System.cmd("git", ["-C", s256, "rev-parse", "--show-toplevel"])
    s256 = String.trim(top)
    s256_dir = Path.join(s256, "receipts")
    put_subject_receipt(s256_dir, repo, "WO-A", digest, "ALIVE", "sha256 copy")
    s256_head = commit!(s256, "WO-A receipt")
    assert s256_head =~ ~r/\A[0-9a-f]{64}\z/

    {code, out} = registry_court(repo, ggen, ["--order-receipts-dir", s256_dir])
    assert code == 0, out
    assert out =~ "order receipts option #{s256_dir} (#{s256} @ #{s256_head})"
    assert out =~ "from=option:#{s256_dir}@#{s256_head}"
    {_stop, orders} = stop_orders(repo)

    assert %{
             "linked" => true,
             "repo" => ^s256,
             "repo_head" => ^s256_head,
             "repo_head_why" => nil,
             "committed_at_head" => true,
             "committed_at_head_why" => nil
           } = orders["WO-A"]
  end
end
