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

  ## `actuate/2` -- a lease may also reach Path A, never by widening Path B

  `admit_tool/2` above is Path B's own hardcoded construction/consequence
  fence (Bash/git_push/publish refused, unchanged by this section). Separately,
  `actuate/2` lets a live lease invoke `Xaas.Actuation.run/4` -- this repo's
  ONE admitted consequential-DO kernel (`Xaas.Actuation`'s moduledoc; also the
  path `Xaas.Marketplace.Changes.ApplyProviderStatusChange` already uses). It
  is not a configurable authority ceiling bolted onto Path B's fence -- it
  grants no new tool allowance and does not touch `@refused_consequence_tools`.
  It is a second, narrower admitted caller of Path A, gated by:

    * an explicit, opt-in, per-provider `{resource, action}` registry
      (`actuation_registry/1`) -- empty by default (fail-closed), same
      real-Application-env convention as `admitted_tools/1`; an unregistered
      pair is `{:error, {:unregistered_actuation, resource, action}}`, never
      silently admitted because Path A alone would separately accept it;
    * Path A's own unmodified admission court
      (`Xaas.Actuation.Kernel.admit/2`'s `FrontierEvidence`/`CausalAdmission`
      validations) -- registering a pair here does not bypass a single one of
      those checks;
    * real, non-empty, lease-provenanced authority evidence built here, never
      caller-supplied `authorize?: true` or an empty authority map (which
      `admit_authority/2` already refuses, `actuation.ex:325-329`).
  """

  require Ash.Query
  require Logger

  alias Xaas.Ultracode.{Epoch, Receipt, Run}

  @default_lease_ttl_minutes 30

  @default_construction_tools ~w(Edit Write Read Grep Glob Task TodoWrite WebFetch)
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

      case Ash.update(
             Ash.Changeset.for_update(epoch, :renew_lease, %{lease_expires_at: expires_at})
           ) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # ------------------------------------------------------------------
  # Admission court
  # ------------------------------------------------------------------

  @doc """
  Per-consequence admission for one proposed provider tool invocation,
  scoped to the LEASE'S OWN provider (`run.provider`).

  `Run.provider` is an unconstrained string field -- the moduledoc already
  names "opencode" as a real second provider alongside "zcode" -- so a
  tool legitimately admitted for one provider must never be silently
  admitted for a request actually coming from a different, unintended
  provider's lease. `admitted_tools/1` is the small per-provider registry
  this fences on; a provider with no explicit entry falls back to
  `@default_construction_tools` unchanged, so this is additive, not a
  breaking narrowing (no provider-specific narrowing is evidenced
  anywhere in this codebase today).

  `{:ok, %{decision: :allow}}` or a typed refusal the caller MUST treat as
  DENY.
  """
  @spec admit_tool(String.t(), String.t()) ::
          {:ok, %{decision: :allow}} | {:error, term()}
  def admit_tool(lease_token, tool) when is_binary(lease_token) and is_binary(tool) do
    with {:ok, epoch} <- live_lease(lease_token, [:run]) do
      cond do
        # Checked BEFORE the operator-configurable admitted_tools/1 lookup,
        # on purpose: @refused_consequence_tools is this domain's one
        # hardcoded, non-configurable floor (moduledoc above). A
        # misconfigured `:ultracode_provider_tools` entry that happens to
        # list "Bash"/"git_push"/"publish" must never be able to defeat it
        # by winning an earlier cond clause -- the refusal always wins.
        tool in @refused_consequence_tools -> {:error, {:refused_no_authority, tool}}
        tool in admitted_tools(epoch.run.provider) -> {:ok, %{decision: :allow}}
        true -> {:error, {:unknown_tool_class, tool}}
      end
    end
  end

  # Per-provider construction-tool vocabulary. Empty by default: no
  # provider-specific narrowing or extension of `@default_construction_tools`
  # is evidenced anywhere in this codebase today, so every named provider
  # ("zcode", "opencode", ...) keeps today's exact admitted-tool behavior
  # unless a real entry is configured. Real per-provider entries are
  # supplied via ordinary Application env
  # (`config :xaas, :ultracode_provider_tools, %{"provider" => [...]}`),
  # the same real per-environment-config mechanism this repo already uses
  # elsewhere (see `config :xaas, :ex4pm_ontology_check` in
  # config/config.exs) -- not a hardcoded guess about a provider's real
  # tool surface, and not a general plugin system.
  defp admitted_tools(provider) do
    :xaas
    |> Application.get_env(:ultracode_provider_tools, %{})
    |> Map.get(provider, @default_construction_tools)
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
  # Actuation (Path A reachability -- see moduledoc)
  # ------------------------------------------------------------------

  @doc """
  Invokes `Xaas.Actuation.run/4` on behalf of a live-leased provider worker,
  for one REGISTERED `{resource, action}` pair only. See the moduledoc's
  "actuate/2" section for what this is and is not.

  `request` (string-keyed, as it arrives off the wire):

    * `"resource"`, `"action"` (required) -- looked up in this lease's
      provider's `actuation_registry/1`; unregistered is a typed refusal.
    * `"input"` -- the action's own input map; a non-map is coerced to `%{}`
      rather than crashing the caller (same fail-closed-not-crash posture as
      `admit_tool/2`'s unknown-class handling).
    * `"idempotency_key"` (required) -- passed straight through;
      `Xaas.Actuation.run/4` itself refuses a missing/blank key.

  There is deliberately no `"subject_id"` wire field. A wire-supplied
  subject would let ANY live lease of a registered provider name an
  arbitrary row of the registered resource -- the registry would gate WHICH
  action runs, never WHICH row it runs against, which is a real broken-
  object-level-authorization gap (a live lease that may flip one Provider's
  status could flip anyone's). The `{resource, action}` registry entry
  itself must supply the subject: `:no_subject` for a subject-less
  (`:create`-shaped) action, or a fixed `subject_id` string decided at
  config time by the operator -- never by the caller of this function. This
  matches the one pre-existing Path A caller in this codebase
  (`Xaas.Marketplace.Changes.ApplyProviderStatusChange`), whose `subject_id`
  is likewise never attacker/caller-controlled wire input.

  Returns exactly what `Xaas.Actuation.run/4` returns: `{:ok, envelope}` with
  real `Ash.Resource`/`ActuationIntent`/`ActuationReceipt` structs for a
  succeeded or replayed attempt, `{:error, reason}` for a refused admission,
  a failed consequential action, or an idempotency conflict.
  """
  @spec actuate(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def actuate(lease_token, request) when is_binary(lease_token) and is_map(request) do
    with {:ok, epoch} <- live_lease(lease_token, [:run]),
         {:ok, resource, action, subject_id} <-
           resolve_registered(epoch.run.provider, request["resource"], request["action"]) do
      authority = %{
        "kind" => "ultracode_lease_actuation",
        "provider" => epoch.run.provider,
        "leased_to" => epoch.leased_to,
        "lease_fingerprint" => lease_fingerprint(lease_token),
        "epoch_id" => epoch.id,
        "run_id" => epoch.run.id
      }

      input = if is_map(request["input"]), do: request["input"], else: %{}

      Xaas.Actuation.run(
        resource,
        action,
        input,
        subject_id: subject_id,
        idempotency_key: request["idempotency_key"],
        authorize?: false,
        authority: authority
      )
    end
  end

  # No atomization of caller input anywhere in this path (unlike a tool
  # name, a `{resource, action}` pair would otherwise mean creating or
  # matching arbitrary module/action atoms from attacker-controlled
  # strings) -- the registry's VALUES already carry the real, operator-
  # configured atoms; lookup is by the raw string pair only. The subject is
  # resolved from the SAME registry entry, never from the wire (see
  # `actuate/2`'s moduledoc section).
  defp resolve_registered(provider, resource, action)
       when is_binary(resource) and is_binary(action) do
    case Map.get(actuation_registry(provider), {resource, action}) do
      {resource_module, action_atom, :no_subject}
      when is_atom(resource_module) and is_atom(action_atom) ->
        {:ok, resource_module, action_atom, nil}

      {resource_module, action_atom, subject_id}
      when is_atom(resource_module) and is_atom(action_atom) and is_binary(subject_id) ->
        {:ok, resource_module, action_atom, subject_id}

      _ ->
        {:error, {:unregistered_actuation, {resource, action}}}
    end
  end

  defp resolve_registered(_provider, resource, action),
    do: {:error, {:unregistered_actuation, {resource, action}}}

  # Per-provider actuation registry -- empty by default (fail-closed): no
  # provider reaches `Xaas.Actuation.run/4` for any `{resource, action}` pair
  # unless an operator explicitly registers it, e.g.
  # `config :xaas, :ultracode_actuation_registry,
  #    %{"zcode" => %{{"Xaas.Marketplace.Provider", "actuate_status"} =>
  #                      {Xaas.Marketplace.Provider, :actuate_status,
  #                       "9c2c0b2e-....-provider-uuid"}}}`
  # -- the same opt-in-only, real per-environment-config mechanism
  # `admitted_tools/1` already uses, independent from it: registering a pair
  # here grants no `admit_tool/2` allowance, and vice versa. The third tuple
  # element is `:no_subject` (subject-less/`:create`-shaped actions) or a
  # fixed subject_id string the OPERATOR names at config time -- see
  # `actuate/2`'s moduledoc for why this can never be wire-supplied.
  defp actuation_registry(provider) do
    :xaas
    |> Application.get_env(:ultracode_actuation_registry, %{})
    |> Map.get(provider, %{})
  end

  # The lease token is itself a bearer capability; never persist it verbatim
  # into actuation evidence (a durable ActuationIntent/Receipt row) -- a
  # one-way fingerprint is enough provenance to bind the actuation to the
  # exact lease that requested it without extending the token's blast radius.
  defp lease_fingerprint(lease_token) do
    :crypto.hash(:sha256, lease_token) |> Base.encode16(case: :lower)
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
             Ash.update(
               Ash.Changeset.for_update(epoch, :record_final_head, %{final_head: final_head})
             ),
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

  defp live_lease(lease_token, load \\ []) do
    case find_by_lease(lease_token, load) do
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

  defp find_by_lease(lease_token, load \\ []) do
    Epoch
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(lease_token == ^lease_token)
    |> Ash.read_one(load: load)
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

        {:build_broken,
         Map.merge(evidence, %{"head_verified" => false, "observed_head" => other_head})}

      {:error, reason} ->
        {:partial_alive,
         Map.merge(evidence, %{
           "head_verified" => false,
           "verifier_unavailable" => inspect(reason)
         })}
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
