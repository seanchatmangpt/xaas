defmodule Xaas.Ultracode.SemanticJiraBridgeIntegrityTest do
  @moduledoc """
  Permanent guards for the bridge's typed-refusal contract (no doubles: the real
  `ggen_igniter` kernel, `Reconciler` and file-backed `TransitionLog`, real files
  and real OS locks; no database).

    * a digest-valid export of the WRONG SHAPE is a typed refusal, never an
      exception: a wrong-typed value at every position the mapping walks;
    * what the log answers is checked against what was asked
      (`acknowledged/3`): a claimed-but-never-written digest is
      `:log_claim_orphaned`, another receipt's event is `:receipt_not_recorded`;
    * the log is a trust root: an event that does not re-derive, a broken standing
      chain or an unreadable file leaves nothing eligible and nothing appendable;
    * a killed writer's orphaned claim is recoverable (`reap_orphaned_claims/1`);
    * concurrent admissions of different receipts for one work order land once.
  """

  use ExUnit.Case, async: false

  alias GgenIgniter.SemanticJira
  alias GgenIgniter.SemanticJira.TransitionLog
  alias Xaas.Ultracode.SemanticJiraBridge, as: Bridge
  alias Xaas.Ultracode.SemanticJiraBridgeFixtures, as: F

  @base F.sha("integrity-base")

  setup do
    dir = F.tmp_dir("integrity-log")
    on_exit(fn -> File.rm_rf(dir) end)

    root = F.work_order("FIX-BROKEN", @base)
    dependent = F.work_order("VERIFY-CLEAN", @base, ["FIX-BROKEN"])
    graph = [root, dependent]

    {:ok, %{execution: root_exec}} = Bridge.descriptor(graph, dir, "FIX-BROKEN", opts(root))

    %{
      dir: dir,
      root: root,
      dependent: dependent,
      graph: graph,
      bridge: root_exec["bridge"],
      export: F.export(root, root_exec["bridge"])
    }
  end

  defp opts(work_order) do
    identity = work_order["identity"]

    [
      execution_repo_alias: "demo",
      verifier_suite: "bridge-suite",
      graph_digest: F.graph_digest(),
      court_map: F.court_map(identity, "check.sh::broken_absent", "check.sh::no_regression")
    ]
  end

  defp admit!(ctx, dir \\ nil) do
    dir = dir || ctx.dir

    assert {:ok, %{event: event, receipt: receipt, disposition: :appended}} =
             Bridge.admit(ctx.graph, "FIX-BROKEN", ctx.export, dir, fabric_check: false)

    {event, receipt}
  end

  defp log_files(dir), do: dir |> File.ls!() |> Enum.filter(&String.ends_with?(&1, ".json"))

  # -- wrong-typed values at every position: a typed refusal, not a crash ------------

  @wrong_values ["oops", 7, ["oops"], %{}, nil, true]

  @paths [
    ["fabric_verifier"],
    ["fabric_verifier", "status"],
    ["fabric_verifier", "steps"],
    ["fabric_verifier", "steps", 0],
    ["fabric_verifier", "steps", 0, "id"],
    ["fabric_verifier", "steps", 0, "status"],
    ["fabric_verifier", "court_receipt"],
    ["fabric_verifier", "court_receipt", "binding"],
    ["fabric_verifier", "court_receipt", "binding", "head"],
    ["fabric_verifier", "court_receipt", "binding", "step_id"],
    ["fabric_verifier", "court_receipt", "binding", "suite"],
    ["fabric_verifier", "court_receipt", "acceptance_results"],
    ["fabric_verifier", "court_receipt", "falsifier_results"],
    ["fabric_verifier", "court_receipt", "court_results"],
    ["fabric_verifier", "court_receipt", "court_results", "COURT"],
    ["fabric_verifier", "court_receipt", "court_results", "COURT", "passed"],
    ["fabric_verifier", "court_receipt", "evidence_types"],
    ["epoch_id"],
    ["run_id"],
    ["receipt_id"],
    ["outcome"],
    ["final_head"],
    ["head_verified"],
    ["bridge"],
    ["bridge", "identity"],
    ["bridge", "definition_digest"],
    ["bridge", "snapshot_digest"],
    ["bridge", "repository"],
    ["bridge", "base_sha"],
    ["bridge", "subject"],
    ["bridge", "requires"],
    ["bridge", "evidence_ceiling"]
  ]

  for path <- @paths do
    test "a wrong-typed value at #{Enum.join(path, ".")} never raises", ctx do
      path = unquote(path) |> Enum.map(&if(&1 == "COURT", do: F.court_iri(), else: &1))

      for value <- @wrong_values do
        forged = F.reseal(ctx.export, &set(&1, path, value))
        dir = F.tmp_dir("integrity-fuzz")

        result =
          try do
            Bridge.admit(ctx.graph, "FIX-BROKEN", forged, dir, fabric_check: false)
          rescue
            exception -> {:raised, exception}
          catch
            kind, reason -> {:raised, {kind, reason}}
          end

        assert match?({:ok, %{disposition: _}}, result) or
                 match?({:error, {:refused_bridge, _}}, result),
               "#{inspect(value)} at #{inspect(path)}: #{inspect(result, limit: 6)}"

        if match?({:error, _}, result), do: assert(TransitionLog.read(dir) == [])
        File.rm_rf(dir)
      end
    end
  end

  test "the typed reason names where the shape is wrong", ctx do
    for {path, value, expected} <- [
          {["fabric_verifier"], "oops", ["fabric_verifier"]},
          {["fabric_verifier", "steps"], "oops", ["fabric_verifier", "steps"]},
          {["fabric_verifier", "court_receipt", "court_results"], ["x"],
           ["fabric_verifier", "court_receipt", "court_results"]},
          {["fabric_verifier", "court_receipt"], 7, ["fabric_verifier", "court_receipt"]}
        ] do
      forged = F.reseal(ctx.export, &set(&1, path, value))

      assert {:error, {:refused_bridge, {:malformed_export, ^expected}}} =
               Bridge.reconciler_receipt(forged, ctx.root)
    end
  end

  test "an export JSON cannot carry has no digest and is refused", ctx do
    forged = Map.put(ctx.export, "extra", self())

    assert {:error, {:refused_bridge, :export_not_json}} =
             Bridge.reconciler_receipt(forged, ctx.root)
  end

  test "a non-string epoch_id is refused before any fabric lookup", ctx do
    forged = F.reseal(ctx.export, &Map.put(&1, "epoch_id", %{"not" => "an id"}))

    assert {:error, {:refused_bridge, {:malformed_export, ["epoch_id"]}}} =
             Bridge.admit(ctx.graph, "FIX-BROKEN", forged, ctx.dir)

    assert TransitionLog.read(ctx.dir) == []
  end

  # -- what the log answers is checked against what was asked ------------------------

  describe "acknowledged/3" do
    test "no event is a claimed-but-never-written digest", ctx do
      {:ok, receipt} = Bridge.reconciler_receipt(ctx.export, ctx.root)
      digest = SemanticJira.digest(receipt)

      assert {:error, {:refused_bridge, {:log_claim_orphaned, ^digest}}} =
               Bridge.acknowledged(nil, :already_recorded, receipt)
    end

    test "an event that cites another receipt is not this receipt's transition", ctx do
      {event, receipt} = admit!(ctx)

      other = Map.put(receipt, "candidate_sha", F.sha("another-candidate"))
      submitted = SemanticJira.digest(other)
      recorded = event["receipt_digest"]

      assert {:error,
              {:refused_bridge,
               {:receipt_not_recorded, %{"submitted" => ^submitted, "recorded" => ^recorded}}}} =
               Bridge.acknowledged(event, :already_recorded, other)
    end

    test "an event that does not re-derive is not trusted even when it cites the receipt", ctx do
      {event, receipt} = admit!(ctx)
      tampered = Map.put(event, "to", "BLOCKED")

      assert {:error, {:refused_bridge, {:log_untrusted, %{"seq" => 1}}}} =
               Bridge.acknowledged(tampered, :appended, receipt)
    end

    test "the event of the submitted receipt is acknowledged", ctx do
      {event, receipt} = admit!(ctx)
      assert {:ok, ^event, :appended} = Bridge.acknowledged(event, :appended, receipt)
    end
  end

  # -- the orphaned claim of a killed writer -----------------------------------------

  test "an orphaned claim is refused with the receipt's digest, then reaped and the receipt lands",
       ctx do
    reference = F.tmp_dir("integrity-reference")
    on_exit(fn -> File.rm_rf(reference) end)
    {reference_event, receipt} = admit!(ctx, reference)

    hex = String.slice(reference_event["event_digest"], 7, 64)
    claim = "digest-#{hex}.claim"
    File.write!(Path.join(ctx.dir, claim), "")

    digest = SemanticJira.digest(receipt)

    assert {:error, {:refused_bridge, {:log_claim_orphaned, ^digest}}} =
             Bridge.admit(ctx.graph, "FIX-BROKEN", ctx.export, ctx.dir, fabric_check: false)

    assert TransitionLog.read(ctx.dir) == []

    assert {:ok, [^claim]} = Bridge.reap_orphaned_claims(ctx.dir)
    refute File.exists?(Path.join(ctx.dir, claim))

    assert {:ok, %{disposition: :appended, event: event}} =
             Bridge.admit(ctx.graph, "FIX-BROKEN", ctx.export, ctx.dir, fabric_check: false)

    assert event["event_digest"] == reference_event["event_digest"]
  end

  test "reaping leaves the claim of a landed event alone", ctx do
    {event, _receipt} = admit!(ctx)
    claim = "digest-#{String.slice(event["event_digest"], 7, 64)}.claim"
    assert File.exists?(Path.join(ctx.dir, claim))

    assert {:ok, []} = Bridge.reap_orphaned_claims(ctx.dir)
    assert File.exists?(Path.join(ctx.dir, claim))
    assert [%{"seq" => 1}] = TransitionLog.read(ctx.dir)
  end

  # -- the log is a trust root -------------------------------------------------------

  describe "a log that does not verify" do
    test "a healthy log verifies: no untrusted marker, dependent eligible", ctx do
      admit!(ctx)
      state = Bridge.state(ctx.graph, ctx.dir)

      refute Map.has_key?(state, "log_untrusted")
      assert state["eligible"] == ["VERIFY-CLEAN"]
    end

    test "a swapped receipt_digest on disk leaves nothing eligible, describable or appendable",
         ctx do
      {event, _} = admit!(ctx)
      [file] = log_files(ctx.dir)
      path = Path.join(ctx.dir, file)

      swapped =
        path |> File.read!() |> Jason.decode!() |> Map.put("receipt_digest", forged_digest())

      File.write!(path, Jason.encode!(swapped))

      assert %{eligible: [], blocked: blocked} = Bridge.frontier(ctx.graph, ctx.dir)
      assert Enum.all?(blocked, &(&1["reason"] == "log_untrusted"))
      assert Enum.map(blocked, & &1["identity"]) == ["FIX-BROKEN", "VERIFY-CLEAN"]

      dependent_opts = opts(ctx.dependent)

      assert {:error, {:refused_bridge, {:log_untrusted, %{"seq" => 1}}}} =
               Bridge.descriptor(ctx.graph, ctx.dir, "VERIFY-CLEAN", dependent_opts)

      state = Bridge.state(ctx.graph, ctx.dir)
      assert state["eligible"] == [] and state["events"] == []
      assert %{"seq" => 1} = state["log_untrusted"]
      assert state["standings"] == %{"FIX-BROKEN" => "UNKNOWN", "VERIFY-CLEAN" => "UNKNOWN"}

      assert {:error, {:refused_bridge, {:log_untrusted, _}}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", ctx.export, ctx.dir, fabric_check: false)

      assert log_files(ctx.dir) == [file]
      assert event["event_digest"] != nil
    end

    test "an event written under the previous digest rule still verifies", ctx do
      {event, _} = admit!(ctx)
      legacy_dir = F.tmp_dir("integrity-legacy")
      on_exit(fn -> File.rm_rf(legacy_dir) end)

      legacy =
        event
        |> Map.drop(["seq", "event_digest"])
        |> then(&Map.put(&1, "event_digest", TransitionLog.legacy_event_digest(&1)))
        |> Map.put("seq", 1)

      refute legacy["event_digest"] == event["event_digest"]

      File.write!(
        Path.join(legacy_dir, "00000001-#{String.slice(legacy["event_digest"], 7, 16)}.json"),
        Jason.encode!(legacy)
      )

      assert ["VERIFY-CLEAN"] ==
               Enum.map(Bridge.frontier(ctx.graph, legacy_dir).eligible, & &1["identity"])
    end

    test "two transitions out of the same standing break the chain", ctx do
      base_event = %{
        "kind" => "standing_transition_event",
        "identity" => "FIX-BROKEN",
        "definition_digest" => forged_digest("d"),
        "snapshot_digest" => forged_digest("s"),
        "from" => "UNKNOWN",
        "to" => "PARTIAL_ALIVE",
        "transition_digest" => forged_digest("t"),
        "authority" => "NONE"
      }

      assert {:ok, _, :appended} =
               TransitionLog.append(
                 ctx.dir,
                 Map.put(base_event, "receipt_digest", forged_digest("a"))
               )

      # a second UNKNOWN -> ...: what an unserialized double admission would leave
      assert {:ok, _, :appended} =
               TransitionLog.append(
                 ctx.dir,
                 base_event
                 |> Map.put("to", "ALIVE")
                 |> Map.put("receipt_digest", forged_digest("b"))
               )

      assert %{eligible: []} = Bridge.frontier(ctx.graph, ctx.dir)

      assert %{"log_untrusted" => %{"discontinuous" => "FIX-BROKEN", "seq" => 2}} =
               Bridge.state(ctx.graph, ctx.dir)
    end

    test "an unreadable event file is refused, not raised", ctx do
      File.mkdir_p!(ctx.dir)
      File.write!(Path.join(ctx.dir, "00000001-aaaaaaaaaaaaaaaa.json"), "{not json")

      assert %{eligible: []} = Bridge.frontier(ctx.graph, ctx.dir)

      assert {:error, {:refused_bridge, {:log_untrusted, %{"unreadable" => _}}}} =
               Bridge.descriptor(ctx.graph, ctx.dir, "FIX-BROKEN", opts(ctx.root))
    end
  end

  # -- concurrent admissions ----------------------------------------------------------

  test "concurrent admissions of different receipts for one work order land exactly once",
       ctx do
    exports =
      for i <- 1..6 do
        F.export(ctx.root, ctx.bridge, head: F.sha("racer-#{i}"), epoch_id: "epoch-#{i}")
      end

    results =
      exports
      |> Task.async_stream(
        &Bridge.admit(ctx.graph, "FIX-BROKEN", &1, ctx.dir, fabric_check: false),
        max_concurrency: 6,
        timeout: 120_000,
        ordered: false
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert [{:ok, %{disposition: :appended}}] = Enum.filter(results, &match?({:ok, _}, &1))

    losers = Enum.reject(results, &match?({:ok, _}, &1))
    assert length(losers) == 5

    assert Enum.all?(
             losers,
             &match?({:error, {:refused_bridge, {:not_on_frontier, "standing=ALIVE"}}}, &1)
           )

    assert [%{"seq" => 1}] = TransitionLog.read(ctx.dir)
    refute Map.has_key?(Bridge.state(ctx.graph, ctx.dir), "log_untrusted")
  end

  test "an admission that cannot take the OS lock is refused and the log is untouched", ctx do
    original = System.get_env("PATH")
    System.put_env("PATH", "/nonexistent-path-for-test")

    try do
      assert {:error, {:refused_bridge, {:log_lock, :perl_unavailable}}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", ctx.export, ctx.dir, fabric_check: false)
    after
      System.put_env("PATH", original)
    end

    assert TransitionLog.read(ctx.dir) == []
  end

  # -- helpers ------------------------------------------------------------------------

  defp forged_digest(seed \\ "forged"),
    do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, seed), case: :lower)

  # put `value` at `path` (string keys for maps, integer indexes for lists)
  defp set(_node, [], value), do: value

  defp set(node, [key | rest], value) when is_map(node) do
    Map.put(node, key, set(Map.get(node, key), rest, value))
  end

  defp set(node, [index | rest], value) when is_list(node) and is_integer(index) do
    List.replace_at(node, index, set(Enum.at(node, index), rest, value))
  end
end
