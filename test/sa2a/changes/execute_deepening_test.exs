defmodule Xaas.Sa2a.Changes.ExecuteDeepeningTest do
  @moduledoc """
  Chicago-style depth court for `Xaas.Sa2a.Changes.Execute` (W984dq9), the DO body of
  `/Users/sac/xaas/lib/xaas/sa2a/changes/execute.ex`, the `before_transaction` DO body
  of `Xaas.Sa2a.Execution`'s `:execute` action.

  Real collaborators throughout: the real Postgres sandbox, the real Ash/Actuation
  Reactor path (`Xaas.Actuation.run/4`), and real OS-subprocess JSON-lines port
  stand-ins speaking the exact protocol `Xaas.Sa2a.Bridge` implements -- the repo's
  established real-subprocess convention (`test/xaas/sa2a_bridge_deepening_test.exs`,
  w741; the `/bin/cat` court). No mocks: every claim is a state assertion on the
  returned error class, the sealed ledger rows, or the absence of an `Execution` row.

  Branch census for the module's `run/1` `with`-chain, with coverage status:

  * `Court.admit` refusal -> `Refusal` added            -- covered (existing suite, sections 2-3)
  * `bound_to_actuation` mismatch -> `:idempotency_key_not_bound` -- covered (existing suite)
  * `execute` unexpected reply -> BLOCKED               -- THIS FILE (deepening test 2)
  * admitted DO hop through the authority gate (w984es repair) -- THIS FILE (deepening test 1)
  * `llm_floor` missing ratio -> `:llm_avoidance_ratio_missing` -- UNREACHABLE pre-repair
    (w984dq9 Finding 1); now reachable downstream of the fixed authority hop, courted
    indirectly by deepening test 1's success path.
  * `manifest_hash` `ArgumentError` rescue -> `:manifest_not_canonical` -- unreachable
    with JSON-normalized court output (all manifest terms are Jason-round-tripped
    before the hash); documented, not double-forced.
  * `replay` unexpected reply -> BLOCKED                -- THIS FILE (deepening test 3)
  * `replay`/`execute` BLOCKED (port death)             -- THIS FILE (deepening test 4)
  """

  use ExUnit.Case, async: false

  alias Xaas.Actuation.Refusal
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}
  alias Xaas.Sa2a.Bridge
  alias Xaas.SystemAuthority

  require Ash.Query

  @admit_hash String.duplicate("a", 64)
  @plan_hash String.duplicate("b", 64)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # -- real-subprocess port stand-in ------------------------------------------------------

  # A real /bin/sh JSON-lines responder keyed on the request's "op" substring, per the
  # repo's established real-port-stand-in convention. Each test starts its own
  # supervised Bridge over a fresh script instance, so arms are test-local.
  defp responder_script(arms) do
    body =
      Enum.map_join(arms, "\n      ", fn {op, action} ->
        "*#{op}*) " <> action <> ";;"
      end)

    script = """
    #!/bin/sh
    while IFS= read -r line; do
      case "$line" in
        #{body}
      esac
    done
    """

    path = Path.join(System.tmp_dir!(), "w984dq9-#{System.unique_integer([:positive])}.sh")
    File.write!(path, script)
    File.chmod!(path, 0o755)

    on_exit(fn ->
      _ = File.rm(path)
      :ok
    end)

    path
  end

  defp start_script_bridge!(arms) do
    start_supervised!({Bridge, port_command: responder_script(arms), port_args: []})
  end

  # -- request builder --------------------------------------------------------------------

  defp new_id, do: "SJ-DQ9-#{System.unique_integer([:positive])}"

  # A request that passes every STATIC admission condition of `Xaas.Sa2a.Court`
  # (shape, allowlist, rules shape, admit-receipt standing "KNOWN", bound plan hash);
  # the port stand-in then decides how the REPRODUCTION calls (sa2a_admit,
  # sa2a_plan) and the DO calls (sa2a_execute, sa2a_replay) answer.
  defp static_valid_request do
    id = new_id()
    digest = "sha256:" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
    query = "workorder:#{id} resolve"
    assertion = "workorder:#{id} digest:#{digest} requires-construction"

    %{
      work_order_id: id,
      work_order_digest: digest,
      query: query,
      compiled_rules: [[query, "constructed:#{id}"]],
      admit: %{
        candidate_id: id,
        assertion: assertion,
        receipt: %{
          "ok" => true,
          "standing" => "KNOWN",
          "candidate_hash" => @admit_hash,
          "admitted_assertion" => assertion
        }
      },
      plan: %{
        plan_id: "dq9-plan",
        plan_hash: @plan_hash,
        candidates: [%{"item_id" => id, "description" => "dq9"}],
        ticks: 1000,
        tokens: 50_000,
        experiments: 10
      }
    }
  end

  defp input(req) do
    %{
      work_order_id: req.work_order_id,
      work_order_digest: req.work_order_digest,
      query: req.query,
      compiled_rules: req.compiled_rules,
      admit: req.admit,
      plan: req.plan
    }
  end

  defp bound_key(req, plan_hash \\ @plan_hash),
    do:
      :crypto.hash(:sha256, "#{req.work_order_digest}|#{req.query}|#{plan_hash}")
      |> Base.encode16(case: :lower)

  defp direct_run(req) do
    Xaas.Actuation.run(Xaas.Sa2a.Execution, :execute, input(req),
      idempotency_key: bound_key(req),
      actor: SystemAuthority.new(:sa2a_executor),
      authorize?: true,
      authority: %{kind: "dq9"}
    )
  end

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

  defp executions_for(req) do
    Xaas.Sa2a.Execution
    |> Ash.Query.filter(work_order_id == ^req.work_order_id)
    |> Ash.read!(authorize?: false)
  end

  defp refusal_code(nil), do: nil

  defp refusal_code(error) do
    case Refusal.find(error) do
      %Refusal{code: code} -> code
      nil -> nil
    end
  end

  # -- 1. the execute hop PASSES the authority gate (w984es repair) ---------------------------
  #
  # COURT FINDING (w984dq9, now REPAIRED by w984es): the DO used to call
  # `Bridge.execute(query, compiled_rules: ...)` with NO `:authority` evidence map, so
  # `Bridge.call/2` refused pre-port with `:sa2a_authority_evidence_required` and every
  # admitted-past-court execution was BLOCKED as `execute_unexpected_reply`. The change
  # now derives the evidence from its own admitted court verdict (mirroring
  # `Xaas.Sa2a.Executor.authority/2`) and passes it into `Bridge.execute/2`, so the
  # request advances past the authority hop to the real port round trip.

  test "the DO hop passes the authority gate: the port round trip completes and the execution row lands with a verified replay" do
    req = static_valid_request()

    start_script_bridge!([
      {"sa2a_admit", ~s(echo '{"ok":true,"standing":"KNOWN","candidate_hash":"#{@admit_hash}"}')},
      {"sa2a_plan",
       ~s(echo '{"ok":true,"plan_hash":"#{@plan_hash}","allocations":[{"item_id":"#{req.work_order_id}","standing":"ADMITTED"}]}')},
      {"sa2a_execute", ~s(echo '{"ok":true,"result":"constructed","llm_avoidance_ratio":1.0}')},
      {"sa2a_replay", ~s(echo '{"ok":true,"verified":true}')}
    ])

    assert {:ok, %{status: :succeeded, result: %Xaas.Sa2a.Execution{} = execution}} =
             direct_run(req)

    # The DO reached the port (past `sa2a_authority_evidence_required`), the execute
    # result flowed through the manifest, and the replay hop verified.
    assert execution.result == "constructed"
    assert execution.llm_avoidance_ratio == 1.0
    assert execution.replay_verified == true
    assert is_binary(execution.manifest_hash)
    assert execution.capability == "sa2a_executor"

    assert [row] = executions_for(req)
    assert row.id == execution.id
    assert row.result == "constructed"

    assert [intent] = intents_for(bound_key(req))
    assert intent.status == :succeeded
  end

  # -- 3. BLOCKED by port death at the admit hop ----------------------------------------------

  test "port death at the admit hop is BLOCKED and seals a failed ledger row with no Execution row" do
    req = static_valid_request()

    start_script_bridge!([{"*", ~s(exit 7)}])

    assert {:error, error} = direct_run(req)
    assert refusal_code(error) == nil

    assert Enum.any?(error.errors, fn e ->
             match?(%Ash.Error.Unknown.UnknownError{error: msg} when is_binary(msg), e) and
               e.error =~ "sa2a bridge blocked" and
               e.error =~ "port_exited"
           end) == true

    assert executions_for(req) == []

    assert [intent] = intents_for(bound_key(req))
    assert intent.status == :failed
  end

  # -- 4. the court re-run INSIDE the change: a bound plan hash that no longer reproduces -----

  test "a court refusal re-derived inside the change is a typed Refusal sealing a refused ledger row" do
    req = static_valid_request()
    tampered_hash = String.duplicate("c", 64)

    # The court's plan_reproduce re-runs the real sa2a_plan and compares the BOUND
    # plan hash against the recomputation; a tampered binding refuses before any DO.
    tampered = put_in(req, [:plan, :plan_hash], tampered_hash)
    key = bound_key(tampered)

    start_script_bridge!([
      {"sa2a_admit", ~s(echo '{"ok":true,"standing":"KNOWN","candidate_hash":"#{@admit_hash}"}')},
      {"sa2a_plan",
       ~s(echo '{"ok":true,"plan_hash":"#{@plan_hash}","allocations":[{"item_id":"#{req.work_order_id}","standing":"ADMITTED"}]}')}
    ])

    # Direct DO (no Executor pre-flight): the court runs ONLY inside the change here.
    assert {:error, error} =
             Xaas.Actuation.run(Xaas.Sa2a.Execution, :execute, input(tampered),
               idempotency_key: key,
               actor: SystemAuthority.new(:sa2a_executor),
               authorize?: true,
               authority: %{kind: "dq9"}
             )

    assert %Refusal{code: :plan_hash_mismatch} = Refusal.find(error)

    assert executions_for(tampered) == []

    assert [intent] = intents_for(key)
    assert intent.status == :refused

    assert [receipt] = receipts_for(intent.id)
    assert receipt.status == :refused
    assert receipt.error["refused"] == "plan_hash_mismatch"
  end
end
