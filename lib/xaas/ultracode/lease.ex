defmodule Xaas.Ultracode.Lease do
  @moduledoc """
  ActuationLease kernel over the existing Ultracode seam.

  This is the missing edge between `EpochReactor`'s Plan and Construct for
  provider-pulled Runs: a provider worker (ZCode plugin, OpenCode CLI, ...)
  claims a `:running` Epoch, holds a bounded construction lease, and closes
  with evidence that becomes the sealed `Xaas.Ultracode.Receipt`.

  It owns no resources of its own:

    * the lease lives ON `Xaas.Ultracode.Epoch` (lease_token /
      lease_expires_at / leased_to / worktree / final_head);
    * the work payload is `Run.goal` + `Epoch.exact_subject`;
    * the closure record is the existing `Xaas.Ultracode.Receipt`.

  Invariants (fail-closed by construction):

    * the lease token is the only capability; every mid-lease operation
      keys on it and a missing/expired lease is a typed refusal;
    * claiming is one filtered bulk UPDATE (`state == :running`, no live
      lease) so two providers cannot win the same epoch — the loser sees
      `{:error, :no_ready_work}` and retries;
    * `admit_tool/2` is per-consequence: construction tools are admitted;
      consequence-class tools are REFUSED — this domain deliberately does
      not model `AuthorityCeiling` (see `EpochReactor`'s :admit doc), so
      the ceiling is a fence, not a configurable grant; unknown tool
      classes are refused (`UNKNOWN != allowed`);
    * closure is head-verified: when the epoch carries a worktree, the
      reported `final_head` is compared against `git rev-parse HEAD`
      before an :alive-family outcome is sealed; mismatch or an
      unavailable verifier downgrades the sealed outcome (falsified
      evidence is :build_broken; unverifiable evidence is
      :partial_alive with the reason in evidence).
  """

  require Ash.Query
  require Logger

  alias Xaas.Ultracode.{Epoch, Receipt, Run}

  @default_lease_ttl_minutes 30

  @construction_tools ~w(Edit Write Read Grep Glob Task TodoWrite WebFetch)
  # Consequence-class tools refused under this domain's no-ceiling fence.
  @refused_consequence_tools ~w(Bash git_push publish)

  # ------------------------------------------------------------------
  # Claim / renew
  # ------------------------------------------------------------------

  @doc """
  Claims the oldest lease-free `:running` Epoch of a provider-pull Run.

  Race-safe: the binding is a single filtered bulk update; see the moduledoc.
  Returns the leased epoch and the lease token, or `{:error,
  :no_ready_work}`.
  """
  @spec claim_next(String.t(), String.t() | nil, keyword()) ::
          {:ok, Epoch.t(), String.t(), Run.t()} | {:error, :no_ready_work | term()}
  def claim_next(provider, worker_id \\ nil, opts \\ [])
      when is_binary(provider) and (is_binary(worker_id) or is_nil(worker_id)) do
    ttl = Keyword.get(opts, :lease_ttl_minutes, @default_lease_ttl_minutes)
    now = DateTime.utc_now()

    query =
      Epoch
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(state == :running)
      |> Ash.Query.filter(is_nil(lease_token) or lease_expires_at < ^now)
      |> Ash.Query.filter(run.provider == ^provider)
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.limit(1)

    with {:ok, candidate} when not is_nil(candidate) <- Ash.read_one(query, load: [:run]) do
      bind_lease(candidate, worker_id, ttl)
    else
      {:ok, nil} -> {:error, :no_ready_work}
      {:error, reason} -> {:error, reason}
    end
  end

  defp bind_lease(%Epoch{} = candidate, worker_id, ttl_minutes) do
    token = lease_token()
    expires_at = DateTime.add(DateTime.utc_now(), ttl_minutes * 60, :second)
    now = DateTime.utc_now()

    # NOTE: bulk_update's :filter must receive the extracted %Ash.Filter{} —
    # passing the whole %Ash.Query{} silently drops the predicate and the
    # UPDATE hits every row (caught live against the sandbox DB).
    result =
      Ash.bulk_update(
        Epoch,
        :lease,
        %{
          lease_token: token,
          lease_expires_at: expires_at,
          leased_to: worker_id || candidate.run.provider
        },
        filter:
          Ash.Query.filter(
            Epoch,
            id == ^candidate.id and state == :running and
              (is_nil(lease_token) or lease_expires_at < ^now)
          )
          |> Map.get(:filter),
        authorize?: false,
        strategy: [:atomic, :atomic_batches, :stream],
        return_records?: true
      )

    case result do
      %{status: :success, records: [%Epoch{} = epoch]} ->
        {:ok, epoch, token, candidate.run}

      %{status: :success, records: []} ->
        {:error, :no_ready_work}

      %{status: :error, errors: errors} ->
        {:error, {:lease_failed, errors}}
    end
  end

  @doc """
  Renews the lease held by `lease_token`.
  """
  @spec renew(String.t()) :: :ok | {:error, term()}
  def renew(lease_token) when is_binary(lease_token) do
    with {:ok, epoch} <- live_lease(lease_token) do
      expires_at = DateTime.add(DateTime.utc_now(), @default_lease_ttl_minutes * 60, :second)

      case Ash.update(Ash.Changeset.for_update(epoch, :renew_lease, %{lease_expires_at: expires_at})) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # ------------------------------------------------------------------
  # Admission court
  # ------------------------------------------------------------------

  @doc """
  Per-consequence admission for one proposed provider tool invocation.

  `{:ok, %{decision: :allow}}` or a typed refusal the caller MUST treat as
  DENY.
  """
  @spec admit_tool(String.t(), String.t()) ::
          {:ok, %{decision: :allow}} | {:error, term()}
  def admit_tool(lease_token, tool) when is_binary(lease_token) and is_binary(tool) do
    with {:ok, _epoch} <- live_lease(lease_token) do
      cond do
        tool in @construction_tools -> {:ok, %{decision: :allow}}
        tool in @refused_consequence_tools -> {:error, {:refused_no_authority, tool}}
        true -> {:error, {:unknown_tool_class, tool}}
      end
    end
  end

  @doc """
  Records a provider-observed event against the lease. Observation, never
  subject success.
  """
  @spec record_provider_event(String.t(), map()) :: :ok | {:error, term()}
  def record_provider_event(lease_token, event) when is_binary(lease_token) do
    case find_by_lease(lease_token) do
      {:ok, epoch} ->
        :telemetry.execute(
          [:xaas, :ultracode, :provider_event],
          %{},
          %{lease_token: lease_token, epoch_id: epoch.id, event: event}
        )

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ------------------------------------------------------------------
  # Closure
  # ------------------------------------------------------------------

  @doc """
  Closes the leased epoch with head-verified evidence and seals the
  Receipt on the existing outcome vocabulary.
  """
  @spec close(String.t(), String.t(), atom(), map()) ::
          {:ok, Epoch.t(), Receipt.t()} | {:error, term()}
  def close(lease_token, final_head, claimed_outcome, evidence \\ %{})
      when is_binary(lease_token) and is_binary(final_head) and is_atom(claimed_outcome) do
    with {:ok, epoch} <- live_lease(lease_token) do
      {outcome, evidence} = verified_outcome(epoch, final_head, claimed_outcome, evidence)

      with {:ok, epoch} <-
             Ash.update(Ash.Changeset.for_update(epoch, :record_final_head, %{final_head: final_head})),
           {:ok, epoch} <- Ash.update(Ash.Changeset.for_update(epoch, :complete, %{})),
           {:ok, receipt} <-
             Receipt
             |> Ash.Changeset.for_create(:seal, %{
               epoch_id: epoch.id,
               subject: epoch.exact_subject,
               outcome: outcome,
               evidence: evidence,
               sealed_at: DateTime.utc_now()
             })
             |> Ash.create() do
        {:ok, epoch, receipt}
      end
    end
  end

  @doc """
  Refuses the leased work: typed standing, epoch lands :failed, receipt
  seals the refusal.
  """
  @spec refuse(String.t(), atom(), map()) :: {:ok, Epoch.t(), Receipt.t()} | {:error, term()}
  def refuse(lease_token, reason, evidence \\ %{})
      when is_binary(lease_token) and is_atom(reason) do
    with {:ok, epoch} <- live_lease(lease_token) do
      with {:ok, epoch} <- Ash.update(Ash.Changeset.for_update(epoch, :mark_failed, %{})),
           {:ok, receipt} <-
             Receipt
             |> Ash.Changeset.for_create(:seal, %{
               epoch_id: epoch.id,
               subject: epoch.exact_subject,
               outcome: :refused,
               evidence: Map.put(evidence, "refusal_reason", Atom.to_string(reason)),
               sealed_at: DateTime.utc_now()
             })
             |> Ash.create() do
        {:ok, epoch, receipt}
      end
    end
  end

  # ------------------------------------------------------------------
  # Lease resolution
  # ------------------------------------------------------------------

  defp live_lease(lease_token) do
    case find_by_lease(lease_token) do
      {:ok, %Epoch{state: :running, lease_expires_at: expires_at} = epoch} ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
          {:error, {:lease_expired, lease_token}}
        else
          {:ok, epoch}
        end

      {:ok, %Epoch{state: state}} when state != :running ->
        {:error, {:lease_not_live, state}}

      {:ok, nil} ->
        {:error, {:no_lease, lease_token}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_by_lease(lease_token) do
    Epoch
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(lease_token == ^lease_token)
    |> Ash.read_one()
  end

  # ------------------------------------------------------------------
  # Closure verification
  # ------------------------------------------------------------------

  defp verified_outcome(%Epoch{} = epoch, final_head, claimed_outcome, evidence) do
    case worktree_head(epoch.worktree) do
      {:ok, ^final_head} ->
        {claimed_outcome, Map.put(evidence, "head_verified", true)}

      {:ok, other_head} ->
        Logger.warning("XAAS_LEASE_CLOSE head mismatch epoch=#{epoch.id}")
        {:build_broken, Map.merge(evidence, %{"head_verified" => false, "observed_head" => other_head})}

      {:error, reason} ->
        {:partial_alive,
         Map.merge(evidence, %{"head_verified" => false, "verifier_unavailable" => inspect(reason)})}
    end
  end

  # Repo-native, shell-free head verification: explicit argv, no shell
  # interpolation; the worktree comes from the epoch row, not the request.
  defp worktree_head(nil), do: {:error, :no_worktree}

  defp worktree_head(worktree) when is_binary(worktree) do
    case System.cmd("git", ["-C", worktree, "rev-parse", "HEAD"], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output |> String.split("\n") |> List.first() |> String.trim()}
      {output, code} -> {:error, {:git_exit, code, String.trim(output)}}
    end
  end

  # ------------------------------------------------------------------
  # Misc
  # ------------------------------------------------------------------

  defp lease_token do
    :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
  end
end
