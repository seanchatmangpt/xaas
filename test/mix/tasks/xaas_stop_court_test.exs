defmodule Mix.Tasks.Xaas.StopCourtTest do
  @moduledoc """
  Chicago-style qualification of `mix xaas.stop_court`: real git repositories in
  tmp, real `/bin/sh` court commands in their own process groups, the real
  `~/.claude/dfcm/validate_receipt.py` (a real `python3` process) and the real
  oxigraph NIF evaluating the REAL `docs/sjira/v26.9.22/friday/stop.rq`. No mocks,
  no stubs. Independent witnesses are real too: receipts are re-validated by a
  separate validator run, the tuple digest is recomputed by Python's
  `json.dumps`, and the ASK -> SELECT rewrite is compared against rdflib's native
  ASK (named skip when rdflib is absent).
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

  # ------------------------------------------------------------------ fixture

  defp repo do
    dir = Path.join(System.tmp_dir!(), "stop_court_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(dir) end)
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

    dir
  end

  defp head(repo) do
    {sha, 0} = System.cmd("git", ["-C", repo, "rev-parse", "HEAD"])
    String.trim(sha)
  end

  defp write_goal(repo, gates, extra \\ "") do
    stop = @stop_rq |> File.read!() |> String.trim()

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

    """
    fri:cap-mix-format a sj:Capability ; sj:capabilityId "recipe:mix-format" .
    fri:WO-1 a sj:WorkOrder ;
        dcterms:identifier "WO-1" ;
        sj:checkpointOf fri:GC-FRI-0800 ;
        sj:subject "fixture:mix-format-drift" ;
        #{postcondition}
        #{successor}
        sj:requiresCapability fri:cap-mix-format ;
        sj:evidenceCeiling "EXECUTED_VERIFIED" ;
        sj:authorityCeiling "CONSTRUCT" ;
        sj:consequenceClass "verification" ;
        sj:exclusion "no network access during the episode", "no LLM on the KNOWN path" .
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
    {:ok, select} = StopCourt.ask_as_select(File.read!(@stop_rq))
    assert select =~ ~r/^PREFIX sj: <https:\/\/ggen-igniter\.dev\/ontology\/semantic-jira#>$/m
    assert select =~ ~r/^SELECT \* \{$/m
    refute select =~ ~r/^ASK\b/m
    assert String.ends_with?(select, "\nLIMIT 1\n")
    assert {:error, :not_an_ask_query} = StopCourt.ask_as_select("SELECT * { ?s ?p ?o }")
  end

  unless @rdflib do
    @tag skip: "needs python3 rdflib for the independent ASK"
  end

  test "the oxigraph SELECT-existence answer equals rdflib's native ASK on the real stop.rq" do
    query = File.read!(@stop_rq)
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
end
