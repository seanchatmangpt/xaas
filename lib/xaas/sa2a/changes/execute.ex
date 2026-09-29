defmodule Xaas.Sa2a.Changes.Execute do
  @moduledoc """
  The DO body of `Xaas.Sa2a.Execution`'s `:execute` action.

  Runs as a `before_transaction` hook, i.e. after `Xaas.Actuation.Validations.ReactorContext`
  has proven the call came through `Xaas.Actuation.Reactor` and after the action policy
  has authorized the actor (Ash authorizes before any hook), but BEFORE the row insert.

  It must not be a `before_action` hook: `Xaas.Actuation.run/4` already holds a Postgres
  transaction, and an error added inside the action's own (joined) transaction makes Ash
  roll the OUTER transaction back, which would destroy the ledger's `:refused` receipt. As a
  `before_transaction` error the changeset is invalid, no `Execution` row is inserted, and
  the control plane seals the refusal durably:

      Court.admit -> idempotency key bound to the actuation context
        -> Bridge.execute (the port DO) -> llm_avoidance_ratio floor
        -> replayable manifest + canonical sha256 -> Bridge.replay(manifest, hash)

  Any violated condition adds a typed `Xaas.Actuation.Refusal`; an unreachable port adds a
  plain error (BLOCKED, sealed `:failed`).
  """

  use Ash.Resource.Change

  alias Xaas.Actuation.Refusal
  alias Xaas.Sa2a.{Bridge, Canonical, Court, ExecutionPolicy}

  @manifest_schema "xaas.sa2a.execution.v1"

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    # The surrounding actuation transaction is by design; silence Ash's generic notice.
    |> Ash.Changeset.set_context(%{warn_on_transaction_hooks?: false})
    |> Ash.Changeset.before_transaction(&run/1)
  end

  defp run(changeset) do
    policy = ExecutionPolicy.config()

    with {:ok, verdict} <- Court.admit(request(changeset), policy),
         :ok <- bound_to_actuation(changeset, verdict),
         {:ok, executed} <- execute(verdict),
         {:ok, ratio} <- llm_floor(executed, policy),
         manifest = manifest(verdict, executed, ratio),
         {:ok, hash} <- manifest_hash(manifest),
         :ok <-
           replay(manifest, hash, Ash.Changeset.get_argument(changeset, :expected_manifest_hash)) do
      Ash.Changeset.force_change_attributes(changeset, %{
        plan_hash: verdict.plan_hash,
        idempotency_key: verdict.idempotency_key,
        class_id: verdict.class_id,
        admit_receipt_id: verdict.admit_receipt_id,
        admit_candidate_hash: verdict.admit_candidate_hash,
        capability: "sa2a_executor",
        result: executed["result"],
        llm_avoidance_ratio: ratio,
        manifest: manifest,
        manifest_hash: hash,
        replay_verified: true
      })
    else
      {:error, {:refused, code, detail}} ->
        Ash.Changeset.add_error(changeset, Refusal.new(code, detail))

      {:error, {:blocked, why}} ->
        Ash.Changeset.add_error(
          changeset,
          Ash.Error.Unknown.UnknownError.exception(error: "sa2a bridge blocked: #{inspect(why)}")
        )
    end
  end

  defp request(changeset) do
    %{
      "work_order_id" => Ash.Changeset.get_attribute(changeset, :work_order_id),
      "work_order_digest" => Ash.Changeset.get_attribute(changeset, :work_order_digest),
      "query" => Ash.Changeset.get_attribute(changeset, :query),
      "compiled_rules" => Ash.Changeset.get_argument(changeset, :compiled_rules),
      "admit" => Ash.Changeset.get_argument(changeset, :admit),
      "plan" => Ash.Changeset.get_argument(changeset, :plan)
    }
  end

  # The actuation ledger's idempotency key must be exactly the court's formula, so the
  # ledger row that guards replay is bound to (work_order_digest, query, plan_hash).
  defp bound_to_actuation(changeset, verdict) do
    key = get_in(changeset.context || %{}, [:xaas_actuation, :idempotency_key])

    if key == verdict.idempotency_key do
      :ok
    else
      {:error, {:refused, :idempotency_key_not_bound, %{"actuation_key" => key}}}
    end
  end

  defp execute(verdict) do
    req = verdict.request
    opts = if verdict.compiled_rules, do: [compiled_rules: verdict.compiled_rules], else: []

    case Court.bridge(fn -> Bridge.execute(req["query"], opts) end) do
      {:ok, %{"ok" => true, "result" => result} = resp} when is_binary(result) -> {:ok, resp}
      {:error, {:blocked, _} = blocked} -> {:error, blocked}
      other -> {:error, {:blocked, {:execute_unexpected_reply, other}}}
    end
  end

  defp llm_floor(%{"llm_avoidance_ratio" => ratio}, policy) when is_number(ratio) do
    if ratio >= policy.min_llm_avoidance_ratio do
      {:ok, ratio}
    else
      {:error,
       {:refused, :llm_fallback_refused,
        %{"llm_avoidance_ratio" => ratio, "required" => policy.min_llm_avoidance_ratio}}}
    end
  end

  defp llm_floor(_executed, _policy),
    do: {:error, {:refused, :llm_avoidance_ratio_missing, nil}}

  defp manifest(verdict, executed, ratio) do
    req = verdict.request

    %{
      "schema" => @manifest_schema,
      "work_order_id" => req["work_order_id"],
      "work_order_digest" => req["work_order_digest"],
      "query" => req["query"],
      "compiled_rules" => verdict.compiled_rules || [],
      "result" => executed["result"],
      "llm_avoidance_ratio" => ratio,
      "plan_hash" => verdict.plan_hash,
      "admit_candidate_hash" => verdict.admit_candidate_hash,
      "idempotency_key" => verdict.idempotency_key
    }
  end

  defp manifest_hash(manifest) do
    {:ok, Canonical.sha256(manifest)}
  rescue
    error in ArgumentError -> {:error, {:refused, :manifest_not_canonical, error.message}}
  end

  # `expected` is the pinned hash of a recorded run when the caller demands an identical
  # re-execution; otherwise the freshly computed canonical hash (cross-checked by the
  # port's own independent canonicalizer).
  defp replay(manifest, computed_hash, expected) do
    expected = expected || computed_hash

    case Court.bridge(fn -> Bridge.replay(manifest, expected) end) do
      {:ok, %{"verified" => true}} ->
        :ok

      {:error, %{"verified" => false} = resp} ->
        {:error,
         {:refused, :replay_mismatch,
          %{"expected" => resp["expected_hash"], "computed" => resp["computed_hash"]}}}

      {:error, {:blocked, _} = blocked} ->
        {:error, blocked}

      other ->
        {:error, {:blocked, {:replay_unexpected_reply, other}}}
    end
  end
end
