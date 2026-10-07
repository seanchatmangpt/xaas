defmodule Xaas.Sa2a.ExecuteTest do
  @moduledoc """
  Chicago-style qualification of the autonomic SA2A `sa2a_execute` DO edge.

  Real collaborators throughout: the real Postgres sandbox, real Ash actions, the real
  `Xaas.Actuation.run/4` Reactor path, and the REAL `autofde beam-bridge` subprocess
  (autofde-lab's port). No test doubles. When `autofde` is not on PATH the whole module is a
  named, visible ExUnit skip -- never a silent substitution.

  Asserts state (ledger rows, sealed receipts, returned values), not interactions.
  """

  use ExUnit.Case, async: false

  alias Xaas.Actuation.Refusal
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}
  alias Xaas.Sa2a.{Bridge, Canonical, Executor, Execution}
  alias Xaas.Sa2a.Generated.EdgeCatalog
  alias Xaas.SystemAuthority

  require Ash.Query

  @autofde System.find_executable("autofde")
  @moduletag skip:
               if(is_nil(@autofde),
                 do:
                   "autofde is not on PATH -- run `export PATH=$HOME/autofde-lab/.venv/bin:$PATH` " <>
                     "(the real beam-bridge subprocess is required; no substitute is used)",
                 else: false
               )

  @query_id "t3-sa2a-execute-test"
  @source "test/xaas/sa2a/execute_test.exs"

  setup_all do
    start_supervised!({Bridge, []})
    :ok
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # -- real-port request builder -------------------------------------------------------

  defp new_id, do: "SJ-T3-#{System.unique_integer([:positive])}"

  # Builds a request whose admit receipt and plan hash come from the real port.
  defp request(opts \\ []) do
    id = Keyword.get(opts, :id, new_id())
    digest = "sha256:" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
    assertion = "workorder:#{id} digest:#{digest} requires-construction"
    evidence = %{"digest" => digest}

    {:ok, receipt} =
      Bridge.admit(id, assertion, query_id: @query_id, source: @source, evidence: evidence)

    candidates = [
      %{
        "item_id" => id,
        "description" => "t3 work order",
        "option_entropy" => 1.0,
        "estimated_cost" => 5.0,
        "historical_yield" => 0.6
      }
    ]

    plan_opts = [plan_id: "t3-plan", ticks: 1000, tokens: 50_000, experiments: 10]
    {:ok, plan} = Bridge.plan(candidates, plan_opts)
    query = "workorder:#{id} resolve"

    %{
      work_order_id: id,
      work_order_digest: digest,
      query: query,
      compiled_rules: [[query, "constructed:#{id}"]],
      admit: %{
        assertion: assertion,
        query_id: @query_id,
        source: @source,
        evidence: evidence,
        receipt: receipt
      },
      plan: %{
        plan_id: "t3-plan",
        plan_hash: plan["plan_hash"],
        candidates: candidates,
        ticks: 1000,
        tokens: 50_000,
        experiments: 10
      }
    }
  end

  defp key_for(req),
    do:
      :crypto.hash(:sha256, "#{req.work_order_digest}|#{req.query}|#{req.plan.plan_hash}")
      |> Base.encode16(case: :lower)

  defp intents_for(key),
    do:
      ActuationIntent
      |> Ash.Query.filter(idempotency_key == ^key)
      |> Ash.read!(authorize?: false)

  defp receipts_for(intent_id),
    do:
      ActuationReceipt
      |> Ash.Query.filter(intent_id == ^intent_id)
      |> Ash.read!(authorize?: false)

  # Scoped to this request's own work order so rows left by other runs of the same
  # private database never make a test depend on global emptiness.
  defp executions_for(req) do
    id = req.work_order_id

    Execution
    |> Ash.Query.filter(work_order_id == ^id)
    |> Ash.read!(authorize?: false)
  end

  # -- 1. admitted path -----------------------------------------------------------------

  test "admitted path executes through the Reactor path, replays, and writes intent + receipt" do
    req = request()
    key = key_for(req)

    assert {:ok, env} = Executor.execute(req)

    assert env.status == :succeeded
    refute env.replay?
    assert env.idempotency_key == key

    exec = env.execution
    assert %Execution{} = exec
    assert exec.result == "constructed:#{req.work_order_id}"
    assert exec.llm_avoidance_ratio == 1.0
    assert exec.replay_verified
    assert exec.idempotency_key == key
    assert exec.capability == "sa2a_executor"
    assert exec.class_id == "sjira-workorder-resolution"
    assert exec.plan_hash == req.plan.plan_hash
    assert exec.admit_candidate_hash == req.admit.receipt["candidate_hash"]

    # The manifest is replayable: the port independently re-derives the recorded hash.
    assert exec.manifest_hash == Canonical.sha256(exec.manifest)
    assert exec.manifest["llm_avoidance_ratio"] == 1.0
    assert {:ok, %{"verified" => true}} = Bridge.replay(exec.manifest, exec.manifest_hash)

    # Ledger: durable intent + sealed receipt bound to the machine authority.
    assert [intent] = intents_for(key)
    assert intent.status == :succeeded
    assert intent.resource_module == "Xaas.Sa2a.Execution"
    assert intent.action == "execute"
    assert intent.authority["capability"] == "sa2a_executor"
    assert intent.authority["plan_hash"] == req.plan.plan_hash
    assert intent.authority["work_order_digest"] == req.work_order_digest

    assert [receipt] = receipts_for(intent.id)
    assert receipt.status == :succeeded
    assert receipt.result_hash
    assert receipt.ontology_projection_hash == Execution.ontology_projection_hash()
    assert receipt.completed_at
  end

  test "a replayed idempotency key returns the sealed receipt and does not re-execute" do
    req = request()
    key = key_for(req)

    assert {:ok, first} = Executor.execute(req)
    assert first.status == :succeeded
    assert length(executions_for(req)) == 1

    assert {:ok, replay} = Executor.execute(req)

    assert replay.status == :replayed
    assert replay.replay?
    assert replay.receipt.id == first.receipt.id
    assert replay.execution.id == first.execution.id
    assert replay.manifest_hash == first.manifest_hash

    # State proof of no second DO: still one Execution row, one intent, one receipt.
    assert length(executions_for(req)) == 1
    assert [intent] = intents_for(key)
    assert length(receipts_for(intent.id)) == 1
  end

  test "the same key with different input is an idempotency conflict, not a re-execution" do
    req = request()
    assert {:ok, _} = Executor.execute(req)

    changed = %{req | compiled_rules: [[req.query, "constructed:DIFFERENT"]]}

    assert {:error, {:idempotency_conflict, key}} = Executor.execute(changed)
    assert key == key_for(req)
    assert length(executions_for(req)) == 1
  end

  # -- 2. capability --------------------------------------------------------------------

  test "every capability other than :sa2a_executor is denied with Ash.Error.Forbidden" do
    req = request()
    key = key_for(req)

    for service <- SystemAuthority.services() -- [:sa2a_executor] do
      assert {:error, %Ash.Error.Forbidden{}} =
               Executor.execute(req, actor: SystemAuthority.new(service)),
             "service #{inspect(service)} must be forbidden"
    end

    # non-system and absent actors carry no capability either
    assert {:error, %Ash.Error.Forbidden{}} = Executor.execute(req, actor: %{id: "not-a-system"})
    assert {:error, %Ash.Error.Forbidden{}} = Executor.execute(req, actor: :nil_actor)

    # The pre-flight denial wrote nothing and did not burn the key.
    assert intents_for(key) == []
    assert executions_for(req) == []
    assert {:ok, %{status: :succeeded}} = Executor.execute(req)
  end

  test "the action itself enforces the capability: a direct Actuation.run with a wrong service is Forbidden" do
    req = request()
    key = key_for(req)

    assert {:error, %Ash.Error.Forbidden{}} =
             Xaas.Actuation.run(Execution, :execute, input(req),
               idempotency_key: key,
               actor: SystemAuthority.new(:webhook_dispatcher),
               authorize?: true,
               authority: %{kind: "test_wrong_service"}
             )

    # Denied inside the DO: durable, but sealed failed and no Execution row exists.
    assert [intent] = intents_for(key)
    assert intent.status == :failed
    assert executions_for(req) == []
  end

  test "authorize?: false alone cannot reach the action without the Reactor context" do
    req = request()

    assert {:error, _} =
             Execution
             |> Ash.Changeset.for_create(:execute, input(req), authorize?: false)
             |> Ash.create(authorize?: false)

    assert executions_for(req) == []
  end

  test "a direct Actuation.run with a key that is not sha256(digest|query|plan_hash) is refused" do
    req = request()

    assert {:error, error} =
             Xaas.Actuation.run(Execution, :execute, input(req),
               idempotency_key: "operator-chosen-key",
               actor: SystemAuthority.new(:sa2a_executor),
               authorize?: true,
               authority: %{kind: "test_unbound_key"}
             )

    assert %Refusal{code: :idempotency_key_not_bound} = Refusal.find(error)
    assert [%{status: :refused}] = intents_for("operator-chosen-key")
    assert executions_for(req) == []
  end

  # -- 3. court refusals (typed, no crash, no ledger row) ----------------------------------

  test "no admit receipt is a typed refusal that creates no ledger row" do
    req = request()
    key = key_for(req)

    for missing <- [Map.delete(req, :admit), put_in(req, [:admit, :receipt], nil)] do
      assert {:error, {:refused, :admit_receipt_missing, _}} = Executor.execute(missing)
    end

    assert intents_for(key) == []
    assert executions_for(req) == []
  end

  test "a tampered admit receipt is not reproducible and is refused" do
    req = request()
    forged = put_in(req, [:admit, :receipt, "candidate_hash"], String.duplicate("a", 64))

    assert {:error, {:refused, :admit_receipt_not_reproducible, %{"expected" => expected}}} =
             Executor.execute(forged)

    assert expected == String.duplicate("a", 64)
    assert intents_for(key_for(req)) == []
  end

  test "an admit receipt for another work-order digest is refused" do
    req = request()
    other = request()

    swapped = %{req | admit: other.admit}
    assert {:error, {:refused, :admit_receipt_digest_mismatch, _}} = Executor.execute(swapped)

    not_known = put_in(req, [:admit, :receipt, "standing"], "REFUSED")
    assert {:error, {:refused, :admit_receipt_not_admitted, _}} = Executor.execute(not_known)
  end

  test "unknown or malformed queries are typed REFUSED, never a crash" do
    req = request()

    assert {:error, {:refused, :query_not_allowlisted, "drop table users"}} =
             Executor.execute(%{req | query: "drop table users"})

    assert {:error, {:refused, :query_not_bound_to_work_order, _}} =
             Executor.execute(%{req | query: "workorder:SJ-SOMEONE-ELSE resolve"})

    long = "workorder:#{req.work_order_id} " <> String.duplicate("x", 600)
    assert {:error, {:refused, :query_too_long, _}} = Executor.execute(%{req | query: long})

    assert {:error, {:refused, :malformed_request, _}} = Executor.execute(%{req | query: 42})
    assert {:error, {:refused, :malformed_request, _}} = Executor.execute(%{})
    assert {:error, {:refused, :malformed_request, _}} = Executor.execute(:not_a_map)

    assert {:error, {:refused, :malformed_compiled_rules, _}} =
             Executor.execute(%{req | compiled_rules: [["only-one"]]})

    assert executions_for(req) == []
  end

  test "a missing, tampered, or non-covering plan is refused" do
    req = request()

    assert {:error, {:refused, :plan_hash_missing, _}} =
             Executor.execute(Map.delete(req, :plan))

    assert {:error, {:refused, :plan_hash_missing, _}} =
             Executor.execute(put_in(req, [:plan, :plan_hash], ""))

    assert {:error, {:refused, :plan_hash_mismatch, %{"bound" => bound}}} =
             Executor.execute(put_in(req, [:plan, :plan_hash], String.duplicate("b", 64)))

    assert bound == String.duplicate("b", 64)

    # a real plan over OTHER candidates does not cover this work order
    others = [
      %{
        "item_id" => "SJ-ELSEWHERE",
        "description" => "x",
        "option_entropy" => 1.0,
        "estimated_cost" => 5.0,
        "historical_yield" => 0.6
      }
    ]

    {:ok, other_plan} =
      Bridge.plan(others, plan_id: "t3-plan", ticks: 1000, tokens: 50_000, experiments: 10)

    uncovered =
      req
      |> put_in([:plan, :candidates], others)
      |> put_in([:plan, :plan_hash], other_plan["plan_hash"])

    assert {:error, {:refused, :plan_does_not_cover_work_order, _}} = Executor.execute(uncovered)
    assert executions_for(req) == []
  end

  # -- 4. post-conditions ---------------------------------------------------------------

  test "a tampered replay hash is refused: receipt sealed :refused, no Execution row" do
    req = request()
    key = key_for(req)
    tampered = String.duplicate("0", 64)

    assert {:error,
            {:refused, :replay_mismatch, %{"expected" => ^tampered, "computed" => computed}}} =
             Executor.execute(Map.put(req, :expected_manifest_hash, tampered))

    assert computed =~ ~r/^[0-9a-f]{64}$/
    refute computed == tampered

    # Rolled back: nothing persisted as an Execution; the ledger records the refusal.
    assert executions_for(req) == []
    assert [intent] = intents_for(key)
    assert intent.status == :refused
    assert [receipt] = receipts_for(intent.id)
    assert receipt.status == :refused
    assert receipt.error["refused"] == "replay_mismatch"

    # A refused execution is terminal for its key (fix-forward: a new plan hash is a new key):
    # the identical request is not replayable, and a different input on that key conflicts.
    pinned = Map.put(req, :expected_manifest_hash, tampered)
    assert {:error, {:idempotency_not_replayable, ^key, :refused}} = Executor.execute(pinned)
    assert {:error, {:idempotency_conflict, ^key}} = Executor.execute(req)
  end

  test "a pinned manifest hash that matches the recorded run is accepted (identical re-execution)" do
    req = request()
    assert {:ok, first} = Executor.execute(req)

    pinned = request()

    assert {:ok, again} =
             Executor.execute(Map.put(pinned, :expected_manifest_hash, expected_hash_for(pinned)))

    assert again.status == :succeeded
    assert again.execution.manifest_hash == expected_hash_for(pinned)
    refute again.execution.id == first.execution.id
  end

  test "a result that fell back to LLM inference (avoidance ratio below the floor) is refused" do
    req = %{request() | compiled_rules: nil}
    key = key_for(req)

    assert {:error, {:refused, :llm_fallback_refused, %{"llm_avoidance_ratio" => ratio}}} =
             Executor.execute(req)

    assert ratio == 0.0
    assert executions_for(req) == []
    assert [%{status: :refused}] = intents_for(key)
  end

  # -- 5. structure: generated contract consumer, sole caller ------------------------------

  test "the generated edge catalog's only DO edge is sa2a_execute and this resource is its sole actuator" do
    assert [%{port_op: "sa2a_execute", from: "Xaas.Sa2a.Bridge.execute"} = edge] =
             EdgeCatalog.do_edges()

    # receipt_before?/receipt_after? are honoured by the actuation ledger (prepared, sealed).
    assert edge.receipt_before?
    assert edge.receipt_after?
    assert edge.replayable?

    assert {:ok, :sa2a_executor} = Xaas.Checks.SystemActor.service_for(Execution, :execute)

    callers =
      Path.wildcard("lib/**/*.ex")
      |> Enum.filter(&(File.read!(&1) =~ "Bridge.execute("))
      |> Enum.sort()

    assert callers == ["lib/xaas/sa2a/changes/execute.ex"],
           "only the admitted Execution action may call the sa2a_execute DO edge, got: #{inspect(callers)}"
  end

  test "the port and Elixir agree on the canonical manifest hash for escapes, unicode and floats" do
    manifest = %{
      "b" => [1, 2.5, 0.001, "quote\" back\\ tab\t nl\n", nil, true],
      "a" => %{"z" => "é ü 漢字 😀", "y" => "\u007f"},
      "ratio" => 0.3333333333333333
    }

    assert {:ok, %{"verified" => true, "computed_hash" => port_hash}} =
             Bridge.replay(manifest, Canonical.sha256(manifest))

    assert port_hash == Canonical.sha256(manifest)
  end

  # -- 6. worker entry point -------------------------------------------------------------

  test "mix xaas.sa2a.execute runs the same path and exits non-zero on refusal" do
    req = request()
    dir = System.tmp_dir!()
    ok_path = Path.join(dir, "sa2a-ok-#{System.unique_integer([:positive])}.json")
    bad_path = Path.join(dir, "sa2a-bad-#{System.unique_integer([:positive])}.json")
    File.write!(ok_path, Jason.encode!(req))
    File.write!(bad_path, Jason.encode!(%{req | query: "not allowlisted"}))

    on_exit(fn ->
      File.rm(ok_path)
      File.rm(bad_path)
    end)

    out = ExUnit.CaptureIO.capture_io(fn -> Mix.Tasks.Xaas.Sa2a.Execute.run([ok_path]) end)
    assert %{"status" => "succeeded", "llm_avoidance_ratio" => 1.0} = Jason.decode!(out)

    out2 = ExUnit.CaptureIO.capture_io(fn -> Mix.Tasks.Xaas.Sa2a.Execute.run([ok_path]) end)
    assert %{"status" => "replayed"} = Jason.decode!(out2)

    refused =
      ExUnit.CaptureIO.capture_io(fn ->
        assert_raise Mix.Error, ~r/refused/, fn -> Mix.Tasks.Xaas.Sa2a.Execute.run([bad_path]) end
      end)

    assert %{"status" => "refused", "code" => "query_not_allowlisted"} = Jason.decode!(refused)
  end

  defp input(req) do
    %{
      work_order_id: req.work_order_id,
      work_order_digest: req.work_order_digest,
      query: req.query,
      compiled_rules: req.compiled_rules,
      admit: Jason.decode!(Jason.encode!(req.admit)),
      plan: Jason.decode!(Jason.encode!(req.plan))
    }
  end

  # The manifest hash a caller can predict for `req` (used to pin an identical re-execution).
  defp expected_hash_for(req) do
    Canonical.sha256(%{
      "schema" => "xaas.sa2a.execution.v1",
      "work_order_id" => req.work_order_id,
      "work_order_digest" => req.work_order_digest,
      "query" => req.query,
      "compiled_rules" => req.compiled_rules,
      "result" => "constructed:#{req.work_order_id}",
      "llm_avoidance_ratio" => 1.0,
      "plan_hash" => req.plan.plan_hash,
      "admit_candidate_hash" => req.admit.receipt["candidate_hash"],
      "idempotency_key" => key_for(req)
    })
  end
end

defmodule Xaas.Sa2a.ExecuteBridgeAbsentTest do
  @moduledoc """
  With no `Xaas.Sa2a.Bridge` port running the executor reports a typed BLOCKED (an
  environment fact), not a crash and not a refusal. Real absence, not a substitute.
  """

  use ExUnit.Case, async: false

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "a missing port is BLOCKED" do
    assert Process.whereis(Xaas.Sa2a.Bridge) == nil

    assert {:error, {:blocked, :bridge_not_running}} =
             Xaas.Sa2a.Executor.execute(%{
               work_order_id: "SJ-X",
               work_order_digest: "sha256:x",
               query: "workorder:SJ-X resolve"
             })
  end
end
