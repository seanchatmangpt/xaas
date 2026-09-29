defmodule Xaas.Sa2a.Executor do
  @moduledoc """
  The autonomic entry point to the SA2A `sa2a_execute` DO edge -- no human in the loop,
  and no bypass of the control plane.

  Every call is routed through `Xaas.Actuation.run/4` (ontology projection -> admission ->
  ActuationIntent/prepared Receipt -> `Ash.Reactor` DO of `Xaas.Sa2a.Execution.:execute`
  -> sealed Receipt -> replay). The machine policy is:

  1. `Xaas.Sa2a.Court.admit/2` -- allowlisted query class, reproducible prior admit
     receipt for the same work-order digest, reproducible bound plan hash. All conditions
     or a typed refusal; a refusal creates no ledger row.
  2. The `:sa2a_executor` capability (`Xaas.SystemAuthority`) is granted to the call only
     after (1) holds. A caller-supplied actor is used as-is and must itself hold the
     capability; any other service is denied with `Ash.Error.Forbidden`.
  3. Idempotency key `sha256(work_order_digest|query|plan_hash)`: a key that already
     succeeded replays its sealed receipt and never re-executes the port.
  4. After the DO, `Bridge.replay(manifest, hash)` runs automatically inside the action; a
     mismatch is a typed refusal that seals the receipt `:refused` and writes no
     `Execution` row.

  Results:

    * `{:ok, %{status: :succeeded | :replayed, execution: %Xaas.Sa2a.Execution{}, ...}}`
    * `{:error, {:refused, code, detail}}` -- typed REFUSED (policy or post-condition)
    * `{:error, {:blocked, why}}` -- environment (`autofde` not on PATH, port down)
    * `{:error, %Ash.Error.Forbidden{}}` -- capability denied
    * `{:error, {:idempotency_conflict, key}}` / `{:idempotency_not_replayable, key, status}`
      -- the key was already used with different input, or already ended `:failed` /
      `:refused` (a refused or failed execution is terminal for its key; a re-derived plan
      hash yields a new key).
  """

  alias Xaas.Actuation.Refusal
  alias Xaas.Sa2a.{Bridge, Court, Execution}
  alias Xaas.SystemAuthority

  @doc """
  Executes `request` autonomically. See `Xaas.Sa2a.Court` for the request shape:

      %{work_order_id: "SJ-001", work_order_digest: "sha256:...", query: "workorder:SJ-001 ...",
        compiled_rules: [["pattern", "output"], ...] | nil,
        admit: %{assertion: ..., query_id: ..., source: ..., evidence: ..., receipt: <sa2a_admit reply>},
        plan: %{plan_id: ..., plan_hash: ..., candidates: [...], ticks: ..., tokens: ..., experiments: ...},
        expected_manifest_hash: "..." | nil}

  Options: `:actor` (default: mint `:sa2a_executor` after the court admits),
  `:start_bridge?` (start the `Xaas.Sa2a.Bridge` port if it is not running).
  """
  @spec execute(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(request, opts \\ []) do
    with {:ok, req} <- Court.normalize(request),
         :ok <- ensure_bridge(Keyword.get(opts, :start_bridge?, false)),
         :ok <- authorized(Keyword.get(opts, :actor)),
         {:ok, verdict} <- Court.admit(req) do
      actor = Keyword.get(opts, :actor) || SystemAuthority.new(:sa2a_executor)

      Execution
      |> Xaas.Actuation.run(:execute, input(req),
        idempotency_key: verdict.idempotency_key,
        actor: actor,
        authorize?: true,
        authority: authority(verdict, req)
      )
      |> shape(verdict)
    end
  end

  @doc "Ensures the `Xaas.Sa2a.Bridge` port is running (typed BLOCKED when it cannot be)."
  @spec ensure_bridge(boolean()) :: :ok | {:error, {:blocked, term()}}
  def ensure_bridge(start? \\ false) do
    cond do
      is_pid(Process.whereis(Bridge)) ->
        :ok

      not start? ->
        {:error, {:blocked, :bridge_not_running}}

      is_nil(System.find_executable("autofde")) ->
        {:error,
         {:blocked, {:autofde_not_on_path, "export PATH=$HOME/autofde-lab/.venv/bin:$PATH"}}}

      true ->
        case Bridge.start_link([]) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, {:blocked, {:bridge_start_failed, reason}}}
        end
    end
  end

  # A supplied actor is checked against the action policy up front so a wrong capability
  # is denied before any intent exists (it cannot burn the request's idempotency key).
  defp authorized(nil), do: :ok

  defp authorized(actor) do
    case Ash.can({Execution, :execute}, actor, run_queries?: false, return_forbidden_error?: true) do
      {:ok, true} -> :ok
      {:ok, false, error} -> {:error, Ash.Error.to_error_class(error)}
      {:ok, false} -> {:error, Ash.Error.to_error_class(Ash.Error.Forbidden.exception([]))}
      other -> {:error, {:authority_check_failed, other}}
    end
  end

  defp input(req) do
    %{
      work_order_id: req["work_order_id"],
      work_order_digest: req["work_order_digest"],
      query: req["query"],
      compiled_rules: req["compiled_rules"],
      admit: req["admit"],
      plan: req["plan"],
      expected_manifest_hash: req["expected_manifest_hash"]
    }
  end

  defp authority(verdict, req) do
    %{
      kind: "machine_policy",
      capability: "sa2a_executor",
      policy: "Xaas.Sa2a.ExecutionPolicy",
      policy_class: verdict.class_id,
      work_order_id: req["work_order_id"],
      work_order_digest: req["work_order_digest"],
      admit_receipt_id: verdict.admit_receipt_id,
      admit_candidate_hash: verdict.admit_candidate_hash,
      plan_hash: verdict.plan_hash
    }
  end

  defp shape({:ok, %{status: status} = envelope}, verdict)
       when status in [:succeeded, :replayed] do
    execution = live_execution(envelope.result)

    {:ok,
     %{
       status: status,
       replay?: envelope.replay?,
       idempotency_key: verdict.idempotency_key,
       execution: execution,
       llm_avoidance_ratio: execution && execution.llm_avoidance_ratio,
       manifest_hash: execution && execution.manifest_hash,
       intent: envelope.intent,
       receipt: envelope.receipt
     }}
  end

  defp shape({:error, reason}, _verdict) do
    case Refusal.find(reason) do
      %Refusal{code: code, detail: detail} -> {:error, {:refused, code, detail}}
      nil -> {:error, reason}
    end
  end

  defp live_execution(%Execution{} = execution), do: execution

  defp live_execution(%{"id" => id}) when is_binary(id),
    do: Ash.get!(Execution, id, authorize?: false)

  defp live_execution(other), do: other
end
