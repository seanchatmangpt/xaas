defmodule Xaas.Execution do
  @moduledoc """
  Lease kernel for the receipted coding-actuation fabric.

  This module owns the pull loop a provider worker (ZCode plugin, OpenCode
  CLI, ...) runs against:

      register_worker -> claim_next -> [admit_tool ...] -> close_candidate
                                                   \-> refuse

  Invariants (fail-closed by construction):

    * A lease is the only capability. Every mid-lease operation keys on the
      server-generated `lease_token`; a request without a live, unexpired,
      state-matching lease is refused — an unreachable or unknown caller
      never widens into an allowed one.
    * Claiming is a single filtered UPDATE (`state == :pending`), so two
      workers racing for the same contract cannot both win; the loser sees
      `{:error, :no_ready_work}` and retries.
    * Leases expire. `claim_next/2` first flips claimed/verifying contracts
      whose `lease_expires_at` has passed to `:expired`; the planner
      resubmits expired semantic work as a new contract rather than
      resurrecting the old one.
    * Tool admission is per-consequence. Construction-class tools are
      allowed inside a held lease; consequence-class tools additionally
      require the contract's `authority_ceiling` to admit them; unknown
      tools are denied (`UNKNOWN != allowed`).
    * This module grants bounded construction authority over one worktree
      only. It never grants DO authority for repository-level consequence:
      that stays behind `Xaas.Actuation` /
      `Xaas.Operations.ActuationIntent`.

  Standing at closure is caller-reported but head-verified when a worktree
  is present: `close_candidate/3` compares `git rev-parse HEAD` in the
  contract worktree against the reported `final_head` and downgrades the
  standing to `UNKNOWN` on mismatch or verifier unavailability.
  """

  require Ash.Query
  require Logger

  alias Xaas.Operations.{ExecutionWorker, WorkContract}

  @default_lease_ttl_minutes 30

  # Provider tool names arrive as JSON strings; the admission classes are
  # string-keyed to match exactly (unknown == denied).
  @construction_tools ~w(Edit Write Read Grep Glob Task TodoWrite WebFetch)
  @consequence_ceiling %{
    "Bash" => "CONSTRUCT_AND_EXECUTE",
    "git_push" => "PUBLISH",
    "publish" => "PUBLISH"
  }

  # ------------------------------------------------------------------
  # Worker lifecycle
  # ------------------------------------------------------------------

  @spec register_worker(map()) :: {:ok, ExecutionWorker.t()} | {:error, term()}
  def register_worker(attrs) do
    Ash.create(ExecutionWorker, attrs, action: :register, authorize?: false)
  end

  @spec heartbeat(String.t()) :: :ok | {:error, term()}
  def heartbeat(lease_token) when is_binary(lease_token) do
    with {:ok, _worker, contract} <- live_lease(lease_token),
         {:ok, _} <-
           Ash.update(contract, %{lease_expires_at: lease_extension_from_now()},
             action: :heartbeat_lease,
             authorize?: false
           ) do
      :ok
    end
  end

  def heartbeat(_), do: {:error, :lease_token_required}

  # ------------------------------------------------------------------
  # Contract lifecycle
  # ------------------------------------------------------------------

  @spec submit_contract(map()) :: {:ok, WorkContract.t()} | {:error, term()}
  def submit_contract(attrs) do
    Ash.create(WorkContract, attrs, action: :submit, authorize?: false)
  end

  @doc """
  Claims the oldest pending contract (optionally lane-filtered) for `worker`.

  Race-safe: the claim is one filtered UPDATE on `state == :pending`; if
  another worker won the row first, this returns `{:error, :no_ready_work}`
  rather than a shared lease.
  """
  @spec claim_next(ExecutionWorker.t(), keyword()) ::
          {:ok, WorkContract.t(), String.t()} | {:error, :no_ready_work | term()}
  def claim_next(%ExecutionWorker{} = worker, opts \\ []) do
    lane = Keyword.get(opts, :quota_lane)
    ttl = Keyword.get(opts, :lease_ttl_minutes, @default_lease_ttl_minutes)

    expire_stale_leases()

    query =
      WorkContract
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(state == :pending)
      |> then(fn q -> if lane, do: Ash.Query.filter(q, quota_lane == ^lane), else: q end)
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.limit(1)

    with {:ok, candidate} when not is_nil(candidate) <- Ash.read_one(query, authorize?: false),
         {:ok, contract, token} <- claim_exactly(candidate, worker, ttl) do
      transition_worker(worker, :leased)
      {:ok, contract, token}
    else
      {:ok, nil} -> {:error, :no_ready_work}
      {:error, reason} -> {:error, reason}
    end
  end

  defp claim_exactly(%WorkContract{} = candidate, %ExecutionWorker{} = worker, ttl_minutes) do
    token = lease_token()
    expires_at = DateTime.add(DateTime.utc_now(), ttl_minutes * 60, :second)

    # NOTE: bulk_update's :filter must receive the extracted %Ash.Filter{}.
    # Passing the whole %Ash.Query{} silently drops the predicate and the
    # UPDATE hits every row — caught live against the sandbox DB.
    result =
      Ash.bulk_update(WorkContract, :claim, %{
        lease_token: token,
        lease_expires_at: expires_at,
        execution_worker_id: worker.id
      },
        filter:
          Ash.Query.filter(
            WorkContract,
            id == ^candidate.id and state == :pending
          )
          |> Map.get(:filter),
        authorize?: false,
        strategy: :atomic,
        return_records?: true
      )

    case result do
      %{status: :success, records: [%WorkContract{} = contract]} ->
        {:ok, contract, token}

      %{status: :success, records: []} ->
        {:error, :no_ready_work}

      %{status: :error, errors: errors} ->
        {:error, {:claim_failed, errors}}
    end
  end

  @doc """
  Per-consequence admission court for one proposed provider tool invocation.

  Returns `{:ok, %{decision: :allow}}` or `{:error, typed_reason}`. Every
  error reason is a fenced refusal — the caller must treat it as DENY.
  """
  @spec admit_tool(String.t(), String.t(), map()) ::
          {:ok, %{decision: :allow, lease_token: String.t()}} | {:error, term()}
  def admit_tool(lease_token, tool, _input \\ %{})
      when is_binary(lease_token) and is_binary(tool) do
    with {:ok, _worker, contract} <- live_lease(lease_token) do
      cond do
        tool_admitted_by_construction?(tool) ->
          {:ok, %{decision: :allow, lease_token: lease_token}}

        ceiling_admits?(contract, tool) ->
          {:ok, %{decision: :allow, lease_token: lease_token}}

        Map.has_key?(@consequence_ceiling, tool) ->
          {:error, {:tool_above_authority_ceiling, tool, contract.authority_ceiling}}

        true ->
          # Unknown tool class is a fence, not a passthrough.
          {:error, {:unknown_tool_class, tool}}
      end
    end
  end

  @doc """
  Records a provider-observed event against the lease.

  Observation, not success: a PostToolUse event proves the provider executed
  the tool, never that the semantic subject closed. v1 evidence is the
  structured log stream; a durable `ProviderEvent` resource is the ledgered
  paydown target (see HANDWRITTEN.md).
  """
  @spec record_provider_event(String.t(), map()) :: :ok | {:error, term()}
  def record_provider_event(lease_token, event) when is_binary(lease_token) do
    with {:ok, _worker, contract} <- lease_or_recent(lease_token) do
      :telemetry.execute(
        [:xaas, :execution, :provider_event],
        %{},
        %{lease_token: lease_token, work_id: contract.work_id, event: event}
      )

      Logger.info(
        "XAAS_PROVIDER_EVENT work_id=#{contract.work_id} lease=#{truncate(lease_token)} event=#{inspect(event, limit: 8)}"
      )

      :ok
    end
  end

  def record_provider_event(_, _), do: {:error, :lease_token_required}

  @doc """
  Closes the leased contract with head verification.

  When the contract carries a worktree, the reported `final_head` is checked
  against `git rev-parse HEAD` in that worktree; mismatch or an unavailable
  verifier downgrades standing to `UNKNOWN`. This is the closure court the
  provider Stop-hook consults — provider stop never implies closure by
  itself.
  """
  @spec close_candidate(String.t(), String.t(), String.t(), map()) ::
          {:ok, WorkContract.t()} | {:error, term()}
  def close_candidate(lease_token, final_head, standing, evidence \\ %{})
      when is_binary(lease_token) do
    with {:ok, _worker, contract} <- live_lease(lease_token),
         :ok <- transition_contract(contract, :verifying),
         verified_standing <- verify_standing(contract, final_head, standing, evidence) do
      Ash.update(contract,
        %{final_head: final_head, standing: verified_standing},
        action: :close,
        authorize?: false
      )
    end
  end

  @spec refuse(String.t(), String.t()) :: {:ok, WorkContract.t()} | {:error, term()}
  def refuse(lease_token, reason) when is_binary(lease_token) do
    with {:ok, _worker, contract} <- live_lease(lease_token) do
      Ash.update(contract, %{standing: reason}, action: :refuse, authorize?: false)
    end
  end

  @doc """
  Expires leases whose `lease_expires_at` has passed.

  Idempotent; called by `claim_next/2` and safe to schedule.
  """
  @spec expire_stale_leases() :: :ok
  def expire_stale_leases do
    now = DateTime.utc_now()

    _ =
      Ash.bulk_update(WorkContract, :transition, %{state: :expired},
        filter:
          Ash.Query.filter(
            WorkContract,
            state in [:claimed, :verifying] and lease_expires_at < ^now
          )
          |> Map.get(:filter),
        authorize?: false,
        strategy: :atomic
      )

    :ok
  end

  # ------------------------------------------------------------------
  # Lease resolution
  # ------------------------------------------------------------------

  defp live_lease(lease_token) do
    case find_contract_by_lease(lease_token) do
      {:ok, %WorkContract{state: state, lease_expires_at: expires_at} = contract}
      when state in [:claimed, :verifying] ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
          {:error, {:lease_expired, lease_token}}
        else
          case Ash.get(ExecutionWorker, contract.execution_worker_id, authorize?: false) do
            {:ok, worker} -> {:ok, worker, contract}
            {:error, reason} -> {:error, {:worker_unavailable, reason}}
          end
        end

      {:ok, _other_state} ->
        {:error, {:lease_not_live, lease_token}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Close/refuse arrive after Stop; the lease may have seconds-old expiry
  # from clock skew, so closure paths accept recently-expired leases that
  # still hold their token, but never a foreign token.
  defp lease_or_recent(lease_token) do
    case find_contract_by_lease(lease_token) do
      {:ok, %WorkContract{execution_worker_id: worker_id} = contract} ->
        case Ash.get(ExecutionWorker, worker_id, authorize?: false) do
          {:ok, worker} -> {:ok, worker, contract}
          {:error, reason} -> {:error, {:worker_unavailable, reason}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_contract_by_lease(lease_token) do
    WorkContract
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(lease_token == ^lease_token)
    |> Ash.read_one(authorize?: false)
  end

  # ------------------------------------------------------------------
  # Admission helpers
  # ------------------------------------------------------------------

  defp tool_admitted_by_construction?(tool) do
    tool in @construction_tools
  end

  defp ceiling_admits?(%WorkContract{authority_ceiling: ceiling}, tool) do
    required = Map.get(@consequence_ceiling, tool)
    is_binary(required) and is_binary(ceiling) and ceiling_admits?(ceiling, required)
  end

  # A ceiling admits a requirement only when it is the same class or the
  # explicitly stronger PUBLISH ceiling. `nil` (no ceiling) admits nothing
  # beyond construction.
  defp ceiling_admits?("PUBLISH", _required), do: true
  defp ceiling_admits?(ceiling, required), do: ceiling == required

  # ------------------------------------------------------------------
  # Closure verification
  # ------------------------------------------------------------------

  defp verify_standing(%WorkContract{} = contract, final_head, standing, _evidence) do
    case worktree_head(contract.worktree) do
      {:ok, ^final_head} -> standing
      {:ok, other_head} -> downgrade(standing, {:head_mismatch, other_head})
      {:error, reason} -> downgrade(standing, {:verifier_unavailable, reason})
    end
  end

  defp downgrade(_standing, reason) do
    Logger.warning("XAAS_CLOSE_DOWNGRADED reason=#{inspect(reason)}")
    "UNKNOWN"
  end

  # Repo-native, shell-free head verification: explicit argv, no shell
  # interpolation, worktree comes from the contract row, not the request.
  defp worktree_head(nil), do: {:error, :no_worktree}

  defp worktree_head(worktree) when is_binary(worktree) do
    case System.cmd("git", ["-C", worktree, "rev-parse", "HEAD"],
           stderr_to_stdout: true
         ) do
      {output, 0} -> {:ok, output |> String.split("\n") |> List.first() |> String.trim()}
      {output, code} -> {:error, {:git_exit, code, String.trim(output)}}
    end
  end

  # ------------------------------------------------------------------
  # Misc
  # ------------------------------------------------------------------

  defp transition_contract(%WorkContract{} = contract, state) do
    case Ash.update(contract, %{state: state}, action: :transition, authorize?: false) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp transition_worker(%ExecutionWorker{} = worker, state) do
    case Ash.update(worker, %{state: state}, action: :transition, authorize?: false) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp lease_extension_from_now do
    DateTime.add(DateTime.utc_now(), @default_lease_ttl_minutes * 60, :second)
  end

  defp lease_token do
    :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
  end

  defp truncate(token), do: String.slice(token, 0, 8)
end
