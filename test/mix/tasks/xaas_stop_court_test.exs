defmodule Mix.Tasks.Xaas.StopCourtTest do
  @moduledoc """
  Chicago-style qualification of `mix xaas.stop_court`: real git repositories in
  tmp, real `/bin/sh` court commands in their own process groups, the real
  `~/.claude/dfcm/validate_receipt.py` (a real `python3` process) and the real
  oxigraph NIF evaluating the STOP contract query. No mocks, no stubs.
  Independent witnesses are real too: receipts are re-validated by a separate
  validator run, the tuple digest is recomputed by Python's `json.dumps`, and the
  ASK -> SELECT rewrite is compared against rdflib's native ASK (named skip when
  rdflib is absent).

  The contract query is pinned in this file (`@contract_stop_rq`) and the fixture
  goal graphs are built from it, so the runner tests depend on no file outside
  `test/`: with the runner absent they fail on the runner itself, not on fixture
  setup. Two tests tie the pin to the real artifacts: the real `stop.rq` must be
  byte-equal (trimmed) to the pin, and the real `goal.ttl` court run must accept
  its root `sj:stopQuery` against that `stop.rq` (the court refuses drift).
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Xaas.StopCourt

  @friday Path.expand("../../../docs/sjira/v26.9.22/friday", __DIR__)
  @stop_rq Path.join(@friday, "stop.rq")
  @goal_ttl Path.join(@friday, "goal.ttl")
  @validator Path.expand("~/.claude/dfcm/validate_receipt.py")

  if not File.regular?(@validator) do
    @moduletag skip: "needs ~/.claude/dfcm/validate_receipt.py (the fleet R-schema validator)"
  end

  @rdflib System.cmd("python3", ["-c", "import rdflib"], stderr_to_stdout: true) |> elem(1) == 0

  @q3 ~s(""")

  # STOP(GC-FRI-0800) contract: byte-equal (trimmed) to docs/sjira/v26.9.22/friday/stop.rq,
  # enforced by "the real stop.rq is the pinned STOP contract" below.
  @contract_stop_rq ~S"""
  # STOP(GC-FRI-0800). True iff (1) GC-FRI-0800 has at least one child gate,
  # (2) every child gate (sj:checkpointOf GC-FRI-0800) has a gate receipt with
  # standing ALIVE, and (3) every WorkOrder with sj:checkpointOf GC-FRI-0800 is
  # typed Successor (sj:boundaryClass sj:Successor) or has a receipt whose
  # standing is terminal: ALIVE, BLOCKED, UNSUPPORTED or REFUSED. UNKNOWN,
  # PARTIAL_ALIVE, BUILD_BROKEN or no receipt at all keeps STOP false.
  # Receipts enter the graph only through mix xaas.stop_court, which projects
  # receipts ADMITTED by validate_receipt.py as sj:Receipt nodes; goal.ttl
  # itself may not assert any receipt. This text is byte-equal (trimmed) to the
  # sj:stopQuery of GC-FRI-0800 in goal.ttl; the court refuses to run on drift.
  PREFIX sj: <https://ggen-igniter.dev/ontology/semantic-jira#>
  PREFIX dcterms: <http://purl.org/dc/terms/>
  ASK {
    ?gc a sj:GoalCheckpoint ;
        dcterms:identifier "GC-FRI-0800" .
    FILTER EXISTS {
      ?anyGate a sj:GoalCheckpoint ;
               sj:checkpointOf ?gc .
    }
    FILTER NOT EXISTS {
      ?gate a sj:GoalCheckpoint ;
            sj:checkpointOf ?gc .
      FILTER NOT EXISTS {
        ?gate sj:receipt ?gateReceipt .
        ?gateReceipt a sj:Receipt ;
                     sj:standing "ALIVE" .
      }
    }
    FILTER NOT EXISTS {
      ?order a sj:WorkOrder ;
             sj:checkpointOf ?gc .
      FILTER NOT EXISTS { ?order sj:boundaryClass sj:Successor . }
      FILTER NOT EXISTS {
        ?order sj:receipt ?orderReceipt .
        ?orderReceipt a sj:Receipt ;
                      sj:standing ?standing .
        FILTER(?standing = "ALIVE" || STRSTARTS(?standing, "BLOCKED") || STRSTARTS(?standing, "UNSUPPORTED") || STRSTARTS(?standing, "REFUSED"))
      }
    }
  }
  """

  # ------------------------------------------------------------------ fixture

  defp repo do
    dir = Path.join(System.tmp_dir!(), "stop_court_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(dir) end)
    File.mkdir_p!(Path.join(dir, "goal"))
    File.write!(Path.join(dir, "goal/stop.rq"), @contract_stop_rq)

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

    dir
  end

  defp head(repo) do
    {sha, 0} = System.cmd("git", ["-C", repo, "rev-parse", "HEAD"])
    String.trim(sha)
  end

  defp write_goal(repo, gates, extra \\ "") do
    stop = String.trim(@contract_stop_rq)

    gate_ttl =
      Enum.map_join(gates, "\n", fn {id, command} ->
        """
        fri:#{id} a sj:GoalCheckpoint ;
            dcterms:identifier "#{id}" ;
            rdfs:label "#{id} fixture gate" ;
            sj:checkpointOf fri:GC-FRI-0800 ;
            sj:boundaryClass sj:Core ;
            sj:courtCommand #{@q3}#{command}#{@q3} .
        """
      end)

    File.write!(Path.join(repo, "goal/goal.ttl"), """
    @prefix sj: <https://ggen-igniter.dev/ontology/semantic-jira#> .
    @prefix fri: <https://ggen-igniter.dev/sjira/v26.9.22/friday#> .
    @prefix dcterms: <http://purl.org/dc/terms/> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

    fri:GC-FRI-0800 a sj:GoalCheckpoint ;
        dcterms:identifier "GC-FRI-0800" ;
        rdfs:label "fixture root" ;
        sj:stopQuery #{@q3}#{stop}#{@q3} .

    #{gate_ttl}
    #{extra}
    """)
  end

  defp args(repo, more \\ []) do
    [
      "--checkpoint",
      "GC-FRI-0800",
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

  defp court(repo, more \\ []) do
    code = make_ref()
    out = capture_io(fn -> send(self(), {code, StopCourt.cli(args(repo, more))}) end)
    assert_received {^code, exit_code}
    {exit_code, out}
  end

  defp validate(paths) do
    {out, code} = System.cmd("python3", [@validator | paths], stderr_to_stdout: true)
    {code, out}
  end

  defp receipt(repo, gate), do: Path.join([repo, "gate-receipts", gate <> ".json"])
  defp read_json(path), do: path |> File.read!() |> Jason.decode!()

  # A full-tuple Friday WorkOrder under the root (exclusions deliberately unsorted).
  defp order_ttl(opts \\ []) do
    postcondition =
      if Keyword.get(opts, :postcondition, true),
        do: ~s(sj:postcondition "mix format --check-formatted exits 0 on the subject" ;),
        else: ""

    successor =
      if Keyword.get(opts, :successor, false), do: "sj:boundaryClass sj:Successor ;", else: ""

    exclusions =
      if Keyword.get(opts, :exclusions, true),
        do: ~s(sj:exclusion "no network access during the episode", "no LLM on the KNOWN path" ;),
        else: ""

    """
    fri:cap-mix-format a sj:Capability ; sj:capabilityId "recipe:mix-format" .
    fri:WO-1 a sj:WorkOrder ;
        dcterms:identifier "WO-1" ;
        sj:checkpointOf fri:GC-FRI-0800 ;
        sj:subject "fixture:mix-format-drift" ;
        #{postcondition}
        #{successor}
        #{exclusions}
        sj:requiresCapability fri:cap-mix-format ;
        sj:evidenceCeiling "EXECUTED_VERIFIED" ;
        sj:authorityCeiling "CONSTRUCT" ;
        sj:consequenceClass "verification" .
    """
  end

  # The tuple digest recomputed INDEPENDENTLY by Python's json.dumps (the contract's
  # reference encoding), never by the module under test.
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

  @wo1_tuple %{
    "subject" => "fixture:mix-format-drift",
    "postcondition" => "mix format --check-formatted exits 0 on the subject",
    "capability" => "recipe:mix-format",
    "evidence_ceiling" => "EXECUTED_VERIFIED",
    "authority_ceiling" => "CONSTRUCT",
    "consequence_class" => "verification",
    "exclusions" => ["no network access during the episode", "no LLM on the KNOWN path"]
  }

  defp write_order_receipt(repo, digest, standing \\ "ALIVE") do
    File.mkdir_p!(Path.join(repo, "order-receipts"))
    sha = head(repo)
    path = Path.join(repo, "order-receipts/WO-1.json")

    File.write!(
      path,
      Jason.encode!(%{
        "identity" => %{
          "subject" => "WO-1",
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

  # ------------------------------------------------------------------ STOP verdicts

  test "a true gate and a false gate: STOP=false, exit 1, both gate receipts ADMITTED" do
    repo = repo()
    write_goal(repo, [{"G1", "true"}, {"G2", "false"}])

    {code, out} = court(repo)

    assert code == 1
    assert out =~ "STOP=false"
    assert out =~ ~r/^G1\s+Core\s+ALIVE\s+0\s/m
    assert out =~ ~r/^G2\s+Core\s+UNKNOWN\s+1\s/m

    # Independent validator run over what the court wrote.
    {vcode, vout} = validate([receipt(repo, "G1"), receipt(repo, "G2")])
    assert vcode == 0, vout
    assert vout =~ "ADMITTED #{receipt(repo, "G1")}"
    assert vout =~ "ADMITTED #{receipt(repo, "G2")}"

    g1 = read_json(receipt(repo, "G1"))
    g2 = read_json(receipt(repo, "G2"))
    assert g1["identity"]["subject"] == "GC-FRI-0800/G1"
    assert g1["identity"]["subject_sha"] == head(repo)
    assert g1["identity"]["graph_hash"] =~ ~r/\Asha256:[0-9a-f]{64}\z/
    assert g1["standing"]["value"] == "ALIVE"
    assert [%{"cmd" => "true", "exit" => 0}] = g1["replay"]["commands"]
    assert g2["standing"]["value"] == "UNKNOWN"
    assert [%{"cmd" => "false", "exit" => 1}] = g2["replay"]["commands"]

    stop = read_json(Path.join(repo, "gate-receipts/STOP-GC-FRI-0800.json"))
    assert stop["standing"]["value"] == "UNKNOWN"
    assert {0, _} = validate([Path.join(repo, "gate-receipts/STOP-GC-FRI-0800.json")])
  end

  test "two true gates: STOP=true, exit 0, STOP receipt ALIVE and ADMITTED" do
    repo = repo()
    write_goal(repo, [{"G1", "true"}, {"G2", "true"}])

    {code, out} = court(repo)

    assert code == 0
    assert out =~ "STOP=true"

    stop_path = Path.join(repo, "gate-receipts/STOP-GC-FRI-0800.json")
    stop = read_json(stop_path)
    assert stop["standing"]["value"] == "ALIVE"
    assert Enum.all?(stop["replay"]["commands"], &(&1["exit"] == 0))
    assert {0, vout} = validate([stop_path, receipt(repo, "G1"), receipt(repo, "G2")])

    assert vout
           |> String.split("\n", trim: true)
           |> Enum.all?(&String.starts_with?(&1, "ADMITTED"))
  end

  test "a missing gate receipt keeps STOP=false even when every gate that ran is ALIVE" do
    repo = repo()
    write_goal(repo, [{"G1", "true"}, {"G2", "true"}])
    assert {0, _} = court(repo)

    File.rm!(receipt(repo, "G2"))
    {code, out} = court(repo, ["--only", "G1"])

    assert code == 1
    assert out =~ "STOP=false"
    assert out =~ ~r/^G1\s+Core\s+ALIVE\s+0\s.*ran/m
    assert out =~ ~r/^G2\s+Core\s+NONE\s+-\s.*MISSING\s+disk/m
  end

  test "a receipt on disk for the wrong subject is not linked (STOP=false)" do
    repo = repo()
    write_goal(repo, [{"G1", "true"}, {"G2", "true"}])
    assert {0, _} = court(repo)

    # G2's slot now holds G1's (valid, ALIVE) receipt: admitted, but not G2's witness.
    File.cp!(receipt(repo, "G1"), receipt(repo, "G2"))
    {code, out} = court(repo, ["--only", "G1"])

    assert code == 1
    assert out =~ ~r/^G2\s.*ADMITTED-UNLINKED/m
  end

  test "a court command that outlives --timeout is killed and recorded UNKNOWN (exit 124)" do
    repo = repo()
    write_goal(repo, [{"G1", "true"}, {"G2", "sleep 30"}])

    started = System.monotonic_time(:millisecond)
    {code, out} = court(repo, ["--timeout", "1"])
    elapsed = System.monotonic_time(:millisecond) - started

    assert code == 1
    assert elapsed < 15_000
    assert out =~ ~r/^G2\s+Core\s+UNKNOWN\s+124\(timeout\)/m

    g2 = read_json(receipt(repo, "G2"))
    assert g2["gate"]["timed_out"] == true
    assert [%{"exit" => 124}] = g2["replay"]["commands"]
    assert {0, _} = validate([receipt(repo, "G2")])
  end

  # ------------------------------------------------------------------ work orders

  test "a WorkOrder under the checkpoint needs an ADMITTED receipt bound to its tuple digest" do
    repo = repo()
    write_goal(repo, [{"G1", "true"}, {"G2", "true"}], order_ttl())
    digest = python_digest(@wo1_tuple)
    assert StopCourt.tuple_digest(@wo1_tuple) == digest

    {code, out} = court(repo)
    assert code == 1, "no order receipt yet"
    assert out =~ "order WO-1 standing=NONE receipt=MISSING digest=#{digest}"

    write_order_receipt(repo, digest)
    {code, out} = court(repo)
    assert code == 0
    assert out =~ "order WO-1 standing=ALIVE receipt=ADMITTED digest=#{digest}"
    assert out =~ "STOP=true"

    # Mutating the bound digest unlinks the receipt: STOP falls back to false.
    write_order_receipt(repo, "sha256:" <> String.duplicate("0", 64))
    {code, out} = court(repo)
    assert code == 1
    assert out =~ "unlinked=:tuple_digest_mismatch"

    # A typed-terminal standing (UNSUPPORTED) with the right digest closes the order too.
    blocked = write_order_receipt(repo, digest, "UNSUPPORTED(generator-capability)")
    assert {0, _} = validate([blocked])
    assert {0, _} = court(repo)
  end

  test "an order with an incomplete tuple is never linked; a Successor-typed order needs no receipt" do
    repo = repo()
    write_goal(repo, [{"G1", "true"}], order_ttl(postcondition: false))
    write_order_receipt(repo, python_digest(@wo1_tuple))

    {code, out} = court(repo)
    assert code == 1
    assert out =~ ~s(unlinked={:incomplete, "postcondition"})

    File.rm!(Path.join(repo, "order-receipts/WO-1.json"))
    write_goal(repo, [{"G1", "true"}], order_ttl(successor: true))
    {code, out} = court(repo)
    assert code == 0
    assert out =~ "successor=true"
  end

  # sj:exclusion is 0..n (lane V23-L aligns the court with the pack shapes):
  # an order without one is tuple-complete with exclusions [] and links on
  # the digest over that empty list.
  test "an order with no sj:exclusion is tuple-complete (exclusions []) and links on its digest" do
    repo = repo()
    write_goal(repo, [{"G1", "true"}], order_ttl(exclusions: false))
    tuple = %{@wo1_tuple | "exclusions" => []}
    digest = python_digest(tuple)
    assert StopCourt.tuple_digest(tuple) == digest
    refute digest == python_digest(@wo1_tuple)

    {code, out} = court(repo)
    assert code == 1
    assert out =~ "order WO-1 standing=NONE receipt=MISSING digest=#{digest}"
    refute out =~ "incomplete"

    write_order_receipt(repo, digest)
    {code, out} = court(repo)
    assert code == 0, out
    assert out =~ "order WO-1 standing=ALIVE receipt=ADMITTED digest=#{digest}"
  end

  # ------------------------------------------------------------------ order receipts dirs (lane V23-L)

  defp git_checkout(prefix) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(dir) end)
    File.mkdir_p!(dir)
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

    toplevel(dir)
  end

  defp toplevel(dir) do
    {top, 0} = System.cmd("git", ["-C", dir, "rev-parse", "--show-toplevel"])
    String.trim(top)
  end

  test "GC-FRI-0800 keeps one order-receipts dir: a receipt only under GGEN_IGNITER_DIR/receipts/v26.9.22 stays MISSING" do
    repo = repo()
    top = toplevel(repo)
    write_goal(repo, [{"G1", "true"}], order_ttl())
    ggen = git_checkout("stop_court_ggen")
    digest = python_digest(@wo1_tuple)

    # No --order-receipts-dir: the registry's single dir under the repository.
    registry_args = fn ->
      args(repo)
      |> Enum.take(8)
      |> Kernel.++(["--ggen-igniter-dir", ggen])
    end

    run = fn ->
      code = make_ref()
      out = capture_io(fn -> send(self(), {code, StopCourt.cli(registry_args.())}) end)
      assert_received {^code, exit_code}
      {exit_code, out}
    end

    {:ok, report} = StopCourt.court(registry_args.())

    assert Enum.map(report.order_receipts_dirs, &{&1.origin, &1.dir}) == [
             {"repo", Path.join(top, "receipts/v26.9.22")}
           ]

    File.mkdir_p!(Path.join(ggen, "receipts/v26.9.22"))
    ggen_receipt = Path.join(ggen, "receipts/v26.9.22/WO-1.json")
    File.cp!(write_order_receipt(repo, digest), ggen_receipt)
    assert {0, _} = validate([ggen_receipt])

    {code, out} = run.()
    assert code == 1
    assert out =~ "order WO-1 standing=NONE receipt=MISSING digest=#{digest}"

    File.mkdir_p!(Path.join(repo, "receipts/v26.9.22"))
    File.cp!(ggen_receipt, Path.join(repo, "receipts/v26.9.22/WO-1.json"))
    {code, out} = run.()
    assert code == 0, out
    assert out =~ "order WO-1 standing=ALIVE receipt=ADMITTED digest=#{digest}"
    assert out =~ "from=repo:#{top}/receipts/v26.9.22@#{head(repo)}"

    # The behaviour above is the preservation claim; the registry entry is its source.
    assert StopCourt.checkpoints()["GC-FRI-0800"].order_receipts_dirs == [
             {:repo, "receipts/v26.9.22"}
           ]
  end

  # ------------------------------------------------------------------ refusals (exit 2)

  test "a goal graph that asserts its own receipt is refused (exit 2), never evaluated" do
    repo = repo()

    write_goal(repo, [{"G1", "false"}], """
    fri:G1 sj:receipt fri:forged .
    fri:forged a sj:Receipt ; sj:standing "ALIVE" .
    """)

    {code, err} = run_stderr(repo)
    assert code == 2
    assert err =~ "graph_asserts_receipts"
    refute File.exists?(receipt(repo, "G1"))
  end

  test "stop.rq drift from the root's sj:stopQuery is refused (exit 2)" do
    repo = repo()
    write_goal(repo, [{"G1", "true"}])
    File.write!(Path.join(repo, "goal/stop.rq"), "ASK { }\n")

    {code, err} = run_stderr(repo)
    assert code == 2
    assert err =~ "stop_query_drift"
  end

  test "an unknown checkpoint and an unknown --only gate are refused (exit 2)" do
    repo = repo()
    write_goal(repo, [{"G1", "true"}])

    {code, err} =
      run_stderr(repo, fn args -> List.replace_at(args, 1, "GC-NOPE") end)

    assert code == 2
    assert err =~ "unknown_checkpoint"

    {code, err} = run_stderr(repo, &(&1 ++ ["--only", "G9"]))
    assert code == 2
    assert err =~ "unknown_gates"
  end

  defp run_stderr(repo, rewrite \\ & &1) do
    code = make_ref()

    err =
      capture_io(:stderr, fn ->
        capture_io(fn -> send(self(), {code, StopCourt.cli(rewrite.(args(repo)))}) end)
      end)

    assert_received {^code, exit_code}
    {exit_code, err}
  end

  # ------------------------------------------------------------------ query engine

  test "ask_as_select keeps the prologue and turns only the ASK keyword into SELECT *" do
    {:ok, select} = StopCourt.ask_as_select(@contract_stop_rq)
    assert select =~ ~r/^PREFIX sj: <https:\/\/ggen-igniter\.dev\/ontology\/semantic-jira#>$/m
    assert select =~ ~r/^SELECT \* \{$/m
    refute select =~ ~r/^ASK\b/m
    assert String.ends_with?(select, "\nLIMIT 1\n")
    assert {:error, :not_an_ask_query} = StopCourt.ask_as_select("SELECT * { ?s ?p ?o }")
  end

  unless @rdflib do
    @tag skip: "needs python3 rdflib for the independent ASK"
  end

  test "the oxigraph SELECT-existence answer equals rdflib's native ASK on the contract query" do
    query = @contract_stop_rq
    {:ok, select} = StopCourt.ask_as_select(query)

    base = """
    <urn:x:root> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://ggen-igniter.dev/ontology/semantic-jira#GoalCheckpoint> .
    <urn:x:root> <http://purl.org/dc/terms/identifier> "GC-FRI-0800" .
    <urn:x:g1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://ggen-igniter.dev/ontology/semantic-jira#GoalCheckpoint> .
    <urn:x:g1> <https://ggen-igniter.dev/ontology/semantic-jira#checkpointOf> <urn:x:root> .
    """

    receipt = fn standing ->
      """
      <urn:x:g1> <https://ggen-igniter.dev/ontology/semantic-jira#receipt> <urn:x:r1> .
      <urn:x:r1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://ggen-igniter.dev/ontology/semantic-jira#Receipt> .
      <urn:x:r1> <https://ggen-igniter.dev/ontology/semantic-jira#standing> "#{standing}" .
      """
    end

    for {nt, expected} <- [
          {base, false},
          {base <> receipt.("UNKNOWN"), false},
          {base <> receipt.("ALIVE"), true}
        ] do
      {:ok, rows} = GgenIgniter.Native.GraphNif.query_turtle(nt, select)

      {py, 0} =
        System.cmd("python3", [
          "-c",
          "import rdflib,sys; g=rdflib.Graph(); g.parse(data=sys.argv[1], format='nt'); print(g.query(sys.argv[2]).askAnswer)",
          nt,
          query
        ])

      assert rows != [] == expected
      assert String.trim(py) == to_string(expected) |> String.capitalize()
    end
  end

  # ------------------------------------------------------------------ the real goal graph

  test "the real stop.rq is the pinned STOP contract (byte-equal, trimmed)" do
    assert File.regular?(@stop_rq), "missing #{@stop_rq}"
    assert String.trim(File.read!(@stop_rq)) == String.trim(@contract_stop_rq)
  end

  test "the real goal.ttl: 13 gates G0..G12, stop.rq in sync, FRI-T5 tuple-complete, STOP=false" do
    receipts =
      Path.join(System.tmp_dir!(), "stop_court_real_#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(receipts) end)

    {:ok, report} =
      StopCourt.court([
        "--checkpoint",
        "GC-FRI-0800",
        "--graph",
        @goal_ttl,
        "--receipts-dir",
        receipts,
        "--only",
        "G0"
      ])

    assert Enum.map(report.gates, & &1.id) == Enum.map(0..12, &"G#{&1}")
    assert Enum.all?(report.gates, &(&1.boundary in ~w(Bootstrap FirstMile Core LastMile)))
    assert Enum.all?(report.gates, &(String.trim(&1.command) != ""))
    assert [%{id: "FRI-T5", tuple: {:ok, tuple, digest}}] = report.orders
    assert tuple["capability"] == "construct:xaas-mix-task"
    assert tuple["consequence_class"] == "manufacture"
    assert digest == python_digest(tuple)
    # Only G0 ran; G1..G12 have no receipt in this fresh dir, so STOP cannot hold.
    assert report.stop == false
    assert Enum.count(report.gates, & &1.ran) == 1
  end

  # ------------------------------------------------------------------ release evidence (lane V23-S)

  # Operator release sequence step 3 (receipts bind subject, graph, verifier
  # and toolchain identity and the replay command) and step 5 (derived
  # counters); ARD sections 12 and 27. Every expected value is recomputed here
  # from the real files, the real VM and a real python3 process.

  @runner_source Path.expand("../../../lib/mix/tasks/xaas.stop_court.ex", __DIR__)
  @schema Path.expand("~/.claude/dfcm/receipt.schema.json")

  defp sha256(bytes), do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  defp commit_all(repo, message) do
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
        "-m",
        message
      ])

    head(repo)
  end

  # G1's court is a committed script file, G2's an inline command.
  defp script_repo do
    repo = repo()
    File.mkdir_p!(Path.join(repo, "courts"))
    File.write!(Path.join(repo, "courts/G1.sh"), "echo 'G1 court ran'\n")
    write_goal(repo, [{"G1", "sh courts/G1.sh"}, {"G2", "true"}])
    commit_all(repo, "courts")
    repo
  end

  defp without_env(name) do
    previous = System.get_env(name)
    System.delete_env(name)
    on_exit(fn -> if previous, do: System.put_env(name, previous) end)
  end

  test "a gate receipt binds the GitHub slug, verifier and toolchain identities and a replay invocation that reproduces it" do
    repo = script_repo()
    top = toplevel(repo)

    {_, 0} =
      System.cmd("git", [
        "-C",
        repo,
        "remote",
        "add",
        "origin",
        "https://github.com/seanchatmangpt/xaas.git"
      ])

    without_env("GC23_FLEET_RECEIPTS_DIR")

    assert {0, _out} = court(repo)
    assert {0, vout} = validate([receipt(repo, "G1")])
    assert vout =~ "ADMITTED"
    g1 = read_json(receipt(repo, "G1"))

    assert %{
             "repo" => "seanchatmangpt/xaas",
             "worktree" => ^top,
             "repo_source" => "git remote origin (github.com)",
             "subject" => "GC-FRI-0800/G1"
           } = g1["identity"]

    assert g1["identity"]["subject_sha"] == head(repo)

    verifier = g1["verifier"]
    assert verifier["runner"] == "mix xaas.stop_court"
    assert verifier["runner_source"] == "lib/mix/tasks/xaas.stop_court.ex"
    assert verifier["runner_source_sha256"] == sha256(File.read!(@runner_source))
    assert verifier["court_command"] == "sh courts/G1.sh"
    assert verifier["court_command_sha256"] == sha256("sh courts/G1.sh")
    assert verifier["court_script"] == "courts/G1.sh"
    assert verifier["court_script_sha256"] == sha256(File.read!(Path.join(repo, "courts/G1.sh")))
    assert verifier["court_script_at_subject"] == true
    assert verifier["court_script_why"] == nil
    assert verifier["validator"] == @validator
    assert verifier["validator_sha256"] == sha256(File.read!(@validator))
    assert verifier["schema"] == @schema
    assert verifier["schema_sha256"] == sha256(File.read!(@schema))
    assert verifier["stop_query_sha256"] == sha256(String.trim(@contract_stop_rq))

    {python, 0} = System.cmd("python3", ["--version"], stderr_to_stdout: true)

    assert g1["toolchain"] == %{
             "elixir" => System.version(),
             "otp_release" => List.to_string(:erlang.system_info(:otp_release)),
             "erts_version" => List.to_string(:erlang.system_info(:version)),
             "python3" => String.trim(python),
             "python3_path" => System.find_executable("python3")
           }

    assert [%{"cmd" => "sh courts/G1.sh", "exit" => 0, "invocation" => invocation} = first] =
             g1["replay"]["commands"]

    assert invocation["cwd"] == File.cwd!()

    {named, others} =
      Map.split(invocation["env"], ~w(MIX_ENV GGEN_IGNITER_DIR GC23_FLEET_RECEIPTS_DIR))

    assert named == %{
             "MIX_ENV" => "test",
             "GGEN_IGNITER_DIR" => g1["gate"]["env"]["GGEN_IGNITER_DIR"],
             "GC23_FLEET_RECEIPTS_DIR" => nil
           }

    # Any other recorded variable is the caller's own GC23_*/DFCM_* value.
    for {name, value} <- others do
      assert String.starts_with?(name, "GC23_") or String.starts_with?(name, "DFCM_")
      assert System.get_env(name) == value
    end

    assert ["mix", "xaas.stop_court", "--checkpoint", "GC-FRI-0800" | rest] = invocation["argv"]
    assert Enum.take(rest, -2) == ["--only", "G1"]
    assert invocation["shell"] =~ "&& env -u GC23_FLEET_RECEIPTS_DIR "
    assert invocation["shell"] =~ " GGEN_IGNITER_DIR=#{g1["gate"]["env"]["GGEN_IGNITER_DIR"]} "

    assert invocation["shell"] =~
             " MIX_ENV=test mix xaas.stop_court --checkpoint GC-FRI-0800 --repo "

    assert String.ends_with?(invocation["shell"], " --only G1")

    # The recorded argv reproduces the receipt: same identities, same output digest.
    code = make_ref()
    capture_io(fn -> send(self(), {code, StopCourt.cli(Enum.drop(invocation["argv"], 2))}) end)
    assert_received {^code, 0}
    again = read_json(receipt(repo, "G1"))
    assert again["identity"] == g1["identity"]
    assert again["verifier"] == g1["verifier"]
    assert again["toolchain"] == g1["toolchain"]

    assert [%{"output_sha256" => digest, "invocation" => ^invocation}] =
             again["replay"]["commands"]

    assert digest == first["output_sha256"]

    # The STOP receipt: same identity and toolchain; its court is the runner itself.
    stop_path = Path.join(repo, "gate-receipts/STOP-GC-FRI-0800.json")
    assert {0, _} = validate([stop_path])
    stop = read_json(stop_path)
    assert stop["identity"]["repo"] == "seanchatmangpt/xaas"
    assert stop["identity"]["worktree"] == top
    assert stop["toolchain"] == g1["toolchain"]
    assert stop["verifier"]["court_command"] == "mix xaas.stop_court --checkpoint GC-FRI-0800"
    assert stop["verifier"]["court_script"] == "lib/mix/tasks/xaas.stop_court.ex"
    assert stop["verifier"]["court_script_sha256"] == sha256(File.read!(@runner_source))
    assert stop["verifier"]["stop_query_sha256"] == verifier["stop_query_sha256"]
    stop_invocation = List.last(stop["replay"]["commands"])["invocation"]
    assert stop_invocation["argv"] == invocation["argv"]
  end

  test "a court script edited after the run changes court_script_sha256; at_subject stays false until the edit is committed" do
    repo = script_repo()
    script = Path.join(repo, "courts/G1.sh")

    assert {0, _} = court(repo)
    before = read_json(receipt(repo, "G1"))["verifier"]
    assert before["court_script_sha256"] == sha256(File.read!(script))
    assert before["court_script_at_subject"] == true

    File.write!(script, File.read!(script) <> "echo 'edited after the run'\n")
    assert {0, _} = court(repo)
    edited_receipt = read_json(receipt(repo, "G1"))
    edited = edited_receipt["verifier"]
    refute edited["court_script_sha256"] == before["court_script_sha256"]
    assert edited["court_script_sha256"] == sha256(File.read!(script))
    assert edited["court_script_at_subject"] == false

    assert edited["court_script_at_subject_why"] ==
             "the bytes differ from the blob at courts/G1.sh in #{head(repo)}"

    assert [%{"summary" => "edited after the run"}] = edited_receipt["replay"]["commands"]
    assert {0, _} = validate([receipt(repo, "G1")])

    commit_all(repo, "edit the G1 court")
    assert {0, _} = court(repo)
    committed = read_json(receipt(repo, "G1"))["verifier"]
    assert committed["court_script_sha256"] == edited["court_script_sha256"]
    assert committed["court_script_at_subject"] == true
    assert committed["court_script_at_subject_why"] == nil
  end

  test "an inline court names no script; without a github.com remote identity.repo stays the worktree; GC-FRI-0800 derives REQUIRED_UNKNOWN only" do
    repo = repo()
    top = toplevel(repo)
    write_goal(repo, [{"G1", "true"}, {"G2", "false"}], order_ttl())

    assert {1, out} = court(repo)

    assert out =~
             "release counters LLM_INVOCATIONS_ON_KNOWN_REFERENCE_PATH=null REQUIRED_LLM_KNOWN=null" <>
               " REQUIRED_UNKNOWN=2 UNCLASSIFIED_REQUIRED_WORK=null UNRECEIPTED_ACTUATION=null"

    g1 = read_json(receipt(repo, "G1"))
    assert g1["identity"]["repo"] == top
    assert g1["identity"]["worktree"] == top

    assert g1["identity"]["repo_source"] ==
             "no github.com remote: identity.repo is the worktree path"

    assert g1["verifier"]["court_script"] == nil
    assert g1["verifier"]["court_script_sha256"] == nil
    assert g1["verifier"]["court_script_at_subject"] == nil
    assert g1["verifier"]["court_script_why"] =~ "inline"
    assert g1["verifier"]["court_command_sha256"] == sha256("true")

    stop_path = Path.join(repo, "gate-receipts/STOP-GC-FRI-0800.json")
    counters = read_json(stop_path)["release_counters"]
    assert counters["REQUIRED_UNKNOWN"]["value"] == 2

    assert counters["REQUIRED_UNKNOWN"]["items"] == [
             "gate G2: UNKNOWN",
             "order WO-1: no linked receipt (MISSING)"
           ]

    for name <-
          ~w(REQUIRED_LLM_KNOWN LLM_INVOCATIONS_ON_KNOWN_REFERENCE_PATH UNRECEIPTED_ACTUATION) do
      assert counters[name]["value"] == nil
      assert counters[name]["why"] == "checkpoint GC-FRI-0800 registers no episodes directory"
    end

    assert counters["UNCLASSIFIED_REQUIRED_WORK"]["value"] == nil

    assert counters["UNCLASSIFIED_REQUIRED_WORK"]["why"] ==
             "checkpoint GC-FRI-0800 registers no fleet classification check (GC23-11)"

    # REQUIRED_UNKNOWN is derived from the run: a bound order receipt removes WO-1.
    write_order_receipt(repo, python_digest(@wo1_tuple))
    assert {1, _} = court(repo)
    assert {0, _} = validate([stop_path])

    assert read_json(stop_path)["release_counters"]["REQUIRED_UNKNOWN"]["items"] == [
             "gate G2: UNKNOWN"
           ]
  end
end
