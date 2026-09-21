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
    * claiming, closing, refusing, and renewing are each ONE real,
      single-statement, DB-enforced `UPDATE ... WHERE <precondition>
      RETURNING *` (`atomic_row_update/2` / `atomic_lease_write/3`) so two
      concurrent callers can never both win the same epoch or the same
      lease_token — the loser sees a typed refusal
      (`{:error, :no_ready_work}` / `{:error, {:lease_stale, _}}`) and
      retries (`claim_next/2` retries a lost bind internally, bounded, as
      long as other ready work may remain). A real 20-way concurrent
      same-row stress test is what this codebase now has for this claim —
      see `atomic_row_update/2`'s own doc for the earlier, real,
      live-DB-confirmed finding that the previous `Ash.bulk_update`-based
      shape here was NOT actually atomic under real contention, despite
      reading as though it were;
    * the provider POOL is capacity-bounded: at most
      `pool_capacity/1` workers may hold live leases per provider at once
      (production config pins 5 -- the operator-ordered standing wave size;
      test config leaves it unbounded so concurrency stress tests keep
      their exact semantics). Over-capacity claims get the typed
      `{:error, :pool_at_capacity}`; the count and the bind serialize under
      one `pg_advisory_xact_lock` per provider so the fence is real under
      concurrency, and slots are released with no separate accounting --
      a slot IS a live lease row (`live_leases/1`), so close/refuse/expiry
      release it by construction;
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
      :partial_alive with the reason in evidence). And under the receipt
      vocabulary law, `:alive` requires a QUALIFYING terminal court --
      head_verified plus a passing registered verifier suite; a close on
      a Run with no suite downgrades an `:alive` claim to `:partial_alive`
      (`verifier_suite_absent` in evidence), and
      `Xaas.Ultracode.Validations.AliveRequiresCourt` refuses at the
      `Receipt.:seal` boundary should any path ever try to seal `:alive`
      without that court.

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

  import Ecto.Query, only: [from: 2]

  alias Xaas.Ultracode.{DurationBudget, Epoch, Receipt, Run, Verifier}

  @default_lease_ttl_minutes 30

  # Pool capacity -- the operator-ordered standing bound on how many workers
  # may be in flight (live leases) per provider at once. This is the
  # ENGINE-level counterpart of the wave's own in-memory semaphore
  # (`Xaas.Ultracode.Autonomic`'s top-up semaphore bounds one wave's batch
  # items; THIS bound lives in the claim kernel, so the MCP `claim_next`
  # path -- which any number of external workers hit concurrently -- is
  # fenced too).
  #
  # Read from `config :xaas, :ultracode_pool_capacity`:
  #   * integer      -- one bound for every provider (production config pins 5);
  #   * map          -- per-provider bounds, `%{default: n}` for unlisted ones;
  #   * nil          -- UNBOUNDED (the config/test.exs default, so the real
  #     `LeaseConcurrencyStressTest`'s 25-way one-provider claim storm keeps
  #     its exact semantics); capacity is a production configuration, not an
  #     implicit test behavior.
  #
  # Enforcement is race-safe by construction: the count and the bind happen
  # inside ONE `pg_advisory_xact_lock` (keyed on the provider string) held
  # for the whole claim -- two concurrent claimers can never both observe a
  # free slot and both bind (the count-of-live-leases predicate alone would
  # race, since a cross-row subselect inside one UPDATE's WHERE clause does
  # not see a concurrent transaction's uncommitted insert of liveness on
  # another row under READ COMMITTED).
  @default_pool_capacity 5

  # Real, evidence-based bound (a live 25-way concurrent `claim_next/2`
  # stress test -- see `LeaseConcurrencyStressTest` -- observed several
  # simultaneous callers reading the SAME globally-oldest candidate before
  # any of them committed; exactly one atomically won the bind, but the
  # losers used to surface `{:error, :no_ready_work}` immediately even
  # while OTHER real ready epochs sat unclaimed). `claim_next/2` retries a
  # LOST bind (never a genuine "no candidate found") up to this many
  # times before failing closed, so a caller does not spuriously fail
  # under real contention while real ready work remains.
  @default_claim_retries 50

  @default_construction_tools ~w(Edit Write Read Grep Glob Task TodoWrite WebFetch)
  # Consequence-class tools refused under this domain's no-ceiling fence.
  @refused_consequence_tools ~w(Bash git_push publish)

  # ------------------------------------------------------------------
  # Claim / renew
  # ------------------------------------------------------------------

  @doc """
  Claims the oldest lease-free `:running` Epoch of a provider-pull Run.

  Race-safe: the binding is one atomic, DB-enforced `UPDATE ... WHERE
  ... RETURNING *` (see the moduledoc and `atomic_row_update/2`); a lost
  race retries (bounded by `:max_retries`, default `@default_claim_retries`)
  as long as other ready work may remain. Returns the leased epoch and the
  lease token, or `{:error, :no_ready_work}`.

  Pool capacity: when the provider's configured capacity
  (`pool_capacity/1`, overridable per call with `:pool_capacity`) is
  non-nil and the number of live leases for the provider already equals
  it, the claim is refused with the typed `{:error, :pool_at_capacity}`
  -- never a silent over-capacity bind. The count and the bind run under
  one `pg_advisory_xact_lock` per provider (see `@default_pool_capacity`'s
  doc), so concurrent claimers cannot both squeeze past the bound.
  `:pool_at_capacity` is deliberately NOT retried (unlike a lost bind):
  capacity being full is terminal for this call -- the caller comes back
  when a slot is released.
  """
  @spec claim_next(String.t(), String.t() | nil, keyword()) ::
          {:ok, Epoch.t(), String.t(), Run.t()}
          | {:error, :no_ready_work | :pool_at_capacity | term()}
  def claim_next(provider, worker_id \\ nil, opts \\ [])
      when is_binary(provider) and (is_binary(worker_id) or is_nil(worker_id)) do
    ttl = Keyword.get(opts, :lease_ttl_minutes, @default_lease_ttl_minutes)
    max_retries = Keyword.get(opts, :max_retries, @default_claim_retries)

    # `:default` sentinel = not supplied -- resolve from config; an explicit
    # `nil` opt means UNBOUNDED for this call, an integer overrides the config.
    capacity =
      case Keyword.get(opts, :pool_capacity, :default) do
        :default -> pool_capacity(provider)
        explicit -> explicit
      end

    do_claim_next(provider, worker_id, ttl, max_retries, Keyword.get(opts, :epoch_id), capacity)
  end

  defp do_claim_next(provider, worker_id, ttl, retries_left, epoch_id, capacity) do
    result =
      Xaas.Repo.transaction(
        fn ->
          # Serialize the capacity check against the bind for this provider
          # pool. A no-op cost when capacity is unbounded (nil) -- the lock
          # is only taken on the enforced path.
          if capacity do
            Xaas.Repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", [
              "ultracode_pool:" <> provider
            ])

            if live_leases(provider) >= capacity do
              {:error, :pool_at_capacity}
            else
              select_and_bind(provider, worker_id, ttl, retries_left, epoch_id)
            end
          else
            select_and_bind(provider, worker_id, ttl, retries_left, epoch_id)
          end
        end,
        timeout: 30_000
      )

    case result do
      {:ok, inner} -> inner
      {:error, reason} -> {:error, reason}
    end
  end

  # The candidate selection + atomic bind loop. Runs INSIDE the per-provider
  # advisory-lock transaction when capacity is enforced (so the lost-bind
  # retries below re-read under the same lock); identical semantics to the
  # original unconditional shape when capacity is nil.
  #
  # `epoch_id` (directed claim) narrows the candidate set to that one epoch:
  # it still has to be running, unleased-or-expired, and of this provider, so
  # it grants nothing an oldest-first claim of the same pool would not -- it
  # only lets a dispatcher that provisioned a worktree for a specific epoch
  # bind its worker to exactly that epoch instead of racing for the oldest.
  defp select_and_bind(provider, worker_id, ttl, retries_left, epoch_id) do
    now = DurationBudget.now()

    query =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(state == :running)
      |> Ash.Query.filter(is_nil(lease_token) or lease_expires_at < ^now)
      |> Ash.Query.filter(run.provider == ^provider)
      # Duration-budget gate (the DB-enforced half of the law in
      # `Xaas.Ultracode.DurationBudget`): a budget-exhausted Run's epochs
      # are NOT ready work -- `run.budget_deadline_at` is the expression
      # calculation mirroring `DurationBudget.deadline/1`, so the exclusion
      # happens in SQL, oldest-candidate-first, with no truncation. A Run
      # with `started_at: nil` has no budget in force (`is_nil` arm --
      # e.g. the Autonomic loop's per-item Runs keep today's behavior).
      |> Ash.Query.filter(is_nil(run.budget_deadline_at) or run.budget_deadline_at > ^now)
      |> then(fn q ->
        if is_binary(epoch_id), do: Ash.Query.filter(q, id == ^epoch_id), else: q
      end)
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.limit(1)

    with {:ok, candidate} when not is_nil(candidate) <- Ash.read_one(query, load: [:run]) do
      case bind_lease(candidate, worker_id, ttl) do
        # Real (not simulated) race, distinguished from genuine exhaustion:
        # a non-nil candidate WAS found above, so the atomic bind losing
        # means a DIFFERENT concurrent caller won this exact row -- other
        # ready epochs may still be unclaimed. Retry re-reads the current
        # candidate set (this row is no longer eligible), converging onto
        # the next-oldest still-available epoch. Bounded: `retries_left ==
        # 0` fails closed rather than spinning forever under pathological,
        # sustained contention.
        {:error, :no_ready_work} when retries_left > 0 ->
          select_and_bind(provider, worker_id, ttl, retries_left - 1, epoch_id)

        other ->
          other
      end
    else
      {:ok, nil} -> {:error, :no_ready_work}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  The provider's configured pool capacity (how many workers may hold live
  leases at once), read from `config :xaas, :ultracode_pool_capacity` --
  integer for all providers, map for per-provider bounds (with `:default`
  for unlisted ones), nil = unbounded. Unset config means #{@default_pool_capacity}.
  """
  @spec pool_capacity(String.t()) :: pos_integer() | nil
  def pool_capacity(provider) when is_binary(provider) do
    case Application.get_env(:xaas, :ultracode_pool_capacity, @default_pool_capacity) do
      nil ->
        nil

      %{} = per_provider ->
        Map.get(per_provider, provider, Map.get(per_provider, :default, @default_pool_capacity))

      capacity when is_integer(capacity) and capacity > 0 ->
        capacity
    end
  end

  @doc """
  How many workers currently hold LIVE leases for this provider -- the
  engine's in-flight slot meter. A lease is live iff its epoch is still
  `:running`, a token is bound, and the TTL has not passed; closure,
  refusal, and TTL expiry each release slots with no separate accounting
  (a slot IS a live lease row, so the meter cannot drift from reality).
  """
  @spec live_leases(String.t()) :: non_neg_integer()
  def live_leases(provider) when is_binary(provider) do
    now = DateTime.utc_now()

    query =
      from(e in Epoch,
        join: r in Run,
        on: e.run_id == r.id,
        where:
          e.state == :running and not is_nil(e.lease_token) and
            e.lease_expires_at >= ^now and r.provider == ^provider,
        select: count(e.id)
      )

    Xaas.Repo.one!(query)
  end

  # ------------------------------------------------------------------
  # Real atomicity primitive -- see this module's `atomic_row_update/2`
  # doc below for the critical finding this replaces.
  # ------------------------------------------------------------------

  defp bind_lease(%Epoch{} = candidate, worker_id, ttl_minutes) do
    token = lease_token()
    expires_at = DateTime.add(DurationBudget.now(), ttl_minutes * 60, :second)
    now = DurationBudget.now()

    result =
      atomic_row_update(
        from(e in Epoch,
          join: r in Run,
          on: r.id == e.run_id,
          # Duration-budget precondition, re-checked ATOMICALLY at the
          # bind (the candidate query's filter alone would leave a
          # check-then-bind window): a Run whose budget expires
          # between the read and this UPDATE loses the bind -- the
          # same fail-closed shape as every other precondition here.
          # Same arithmetic as `DurationBudget.deadline/1` and the
          # `budget_deadline_at` calculation.
          where:
            e.id == ^candidate.id and e.state == :running and
              (is_nil(e.lease_token) or e.lease_expires_at < ^now) and
              (is_nil(r.started_at) or
                 fragment(
                   "? + (? * interval '1 second')",
                   r.started_at,
                   r.duration_budget_seconds
                 ) > ^now)
        ),
        lease_token: token,
        lease_expires_at: expires_at,
        leased_to: worker_id || candidate.run.provider,
        # The bind moment, persisted in the SAME single atomic UPDATE that
        # binds the lease (atomicity preserved -- one statement, one row
        # lock). This is the fact the OCEL egress's `epoch_claimed` event
        # derives from; before this column the bind wrote no timestamp and
        # the event could only be declared, never emitted. A re-claim of an
        # expired lease overwrites it with the new claim's moment.
        claimed_at: now
      )

    case result do
      {:ok, epoch} -> {:ok, epoch, token, candidate.run}
      {:error, :no_match} -> {:error, :no_ready_work}
    end
  end

  # Real concurrency-hardening primitive shared by `bind_lease/3` above
  # and `close/4`/`refuse/3`/`renew/1` below.
  #
  # CRITICAL FINDING (real, live-DB-verified, not reasoned): the ORIGINAL
  # shape here -- and `bind_lease/3`'s ORIGINAL shape, which this module's
  # own moduledoc and an earlier session both called "race-safe" /
  # "confirmed safe against double-binding" -- was a filtered
  # `Ash.bulk_update/4` call with `strategy: [:atomic, :atomic_batches,
  # :stream]`. Neither `Xaas.Ultracode.Validations.LeaseAvailable` nor
  # `EpochTransitionAllowed` implements `Ash.Resource.Validation`'s
  # `atomic/3` callback, so Ash can never compile `:atomic`/
  # `:atomic_batches` for `:lease`/`:complete`/`:mark_failed` -- every real
  # call silently falls through to the `:stream` strategy. `:stream` uses
  # the filter ONLY to select a candidate batch (a plain SELECT); the
  # per-row write that follows is an ordinary `Ash.update` BY PRIMARY KEY
  # with no filter/precondition re-applied as part of the actual UPDATE
  # statement -- so it carries NO real atomicity at all. A real 20-way
  # `Task.async_stream` claiming ONE row (`LeaseConcurrencyStressTest`
  # would reproduce this; first found via a standalone diagnostic script)
  # showed 6-19 of 20 concurrent callers all "winning" the SAME row -- the
  # earlier "0/3 collisions" evidence this module's moduledoc cited was
  # real but simply too low-contention to ever hit the gap; it was never
  # proof of atomicity.
  #
  # The fix: a genuinely atomic, single-statement, DB-enforced
  # `UPDATE ... WHERE <precondition> RETURNING *` via `Ecto.Query` +
  # `Xaas.Repo.update_all/2` directly -- proven atomic under real 20-way
  # same-row contention (exactly 1 winner, every real trial) where the
  # `Ash.bulk_update` shape was not. This deliberately bypasses Ash's
  # changeset/validation pipeline for this one write (`Epoch` carries no
  # notifiers/`after_action` hooks on these actions to lose by doing so --
  # confirmed by inspection), reimplementing the SAME precondition the
  # bypassed Ash validation expressed, now enforced by Postgres itself
  # rather than trusted from an earlier, unsynchronized read.
  @spec atomic_row_update(Ecto.Query.t(), keyword()) :: {:ok, Epoch.t()} | {:error, :no_match}
  defp atomic_row_update(%Ecto.Query{} = base_query, set_fields) do
    now = DateTime.utc_now()
    set_fields = Keyword.put_new(set_fields, :updated_at, now)

    query =
      from(e in base_query,
        update: [set: ^set_fields],
        select: e
      )

    case Xaas.Repo.update_all(query, []) do
      {1, [%Epoch{} = updated]} -> {:ok, updated}
      {0, _} -> {:error, :no_match}
    end
  end

  @spec atomic_lease_write(Epoch.t(), String.t(), keyword()) ::
          {:ok, Epoch.t()} | {:error, term()}
  defp atomic_lease_write(%Epoch{} = epoch, lease_token, set_fields) do
    result =
      atomic_row_update(
        from(e in Epoch,
          where: e.id == ^epoch.id and e.lease_token == ^lease_token and e.state == :running
        ),
        set_fields
      )

    case result do
      {:ok, updated} -> {:ok, updated}
      {:error, :no_match} -> {:error, {:lease_stale, lease_token}}
    end
  end

  @doc """
  Renews the lease held by `lease_token`.
  """
  @spec renew(String.t()) :: :ok | {:error, term()}
  def renew(lease_token) when is_binary(lease_token) do
    with {:ok, epoch} <- live_lease(lease_token) do
      now = DateTime.utc_now()
      expires_at = DateTime.add(now, @default_lease_ttl_minutes * 60, :second)

      case atomic_lease_write(epoch, lease_token,
             lease_expires_at: expires_at,
             # The heartbeat moment, persisted in the same atomic write that
             # extends the TTL -- the OCEL egress's `worker_heartbeat` event
             # time. One column keeps the LATEST renewal's moment (renewal
             # history deliberately collapses into it; see the attribute doc).
             last_heartbeat_at: now
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
    with {:ok, epoch} <- live_lease(lease_token, [:run]) do
      {outcome, evidence} = verified_outcome(epoch, final_head, claimed_outcome, evidence)
      evidence = bind_semantic_work_identity(epoch, evidence)

      # Real finding, real-concurrency-tested (see `LeaseConcurrencyStressTest`
      # "concurrent close/refuse on the same lease_token"): the previous
      # shape here was TWO separate, unguarded `Ash.update` calls
      # (`:record_final_head` then `:complete`) after `live_lease/2`'s
      # check -- neither write re-verified `lease_token` ownership, so two
      # concurrent `close/4` calls on the SAME token (a double-submit or
      # retry storm), or a stale caller racing a legitimate re-claim,
      # could both land, sealing two Receipts for one epoch. The write now
      # goes through `atomic_lease_write/3` -- a genuinely atomic,
      # single-statement `UPDATE ... WHERE lease_token = ... AND state =
      # 'running' ... RETURNING *` (see that function's doc for why the
      # obvious-looking `Ash.bulk_update` alternative does NOT actually
      # provide this). Zero rows matched (lease reassigned, or already
      # closed by a concurrent winner) is a real, typed
      # `{:error, {:lease_stale, _}}` refusal, never a silent duplicate
      # write.
      with {:ok, epoch} <-
             atomic_lease_write(epoch, lease_token,
               state: :completed,
               completed_at: DateTime.utc_now(),
               final_head: final_head
             ),
           {:ok, receipt} <-
             Receipt
             |> Ash.Changeset.for_create(:seal, %{
               epoch_id: epoch.id,
               subject: epoch.exact_subject,
               outcome: outcome,
               evidence: evidence,
               sealed_at: DateTime.utc_now()
             })
             |> Ash.create(actor: Xaas.SystemAuthority.new(:ultracode_reactor)) do
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
    with {:ok, epoch} <- live_lease(lease_token, [:run]) do
      evidence = bind_semantic_work_identity(epoch, evidence)

      # Same atomic lease-token-guarded write as `close/4` above -- closes
      # the identical real double-close race for the refuse path (and for
      # a `close/4` racing a `refuse/3` on the same token). `terminal_at`
      # is this transition's own persisted moment (the egress's
      # `epoch_failed` event time -- same dedicated column `:mark_failed`
      # writes; `updated_at` was only ever an approximation of it).
      with {:ok, epoch} <-
             atomic_lease_write(epoch, lease_token,
               state: :failed,
               terminal_at: DateTime.utc_now()
             ),
           {:ok, receipt} <-
             Receipt
             |> Ash.Changeset.for_create(:seal, %{
               epoch_id: epoch.id,
               subject: epoch.exact_subject,
               outcome: :refused,
               evidence: Map.put(evidence, "refusal_reason", Atom.to_string(reason)),
               sealed_at: DateTime.utc_now()
             })
             |> Ash.create(actor: Xaas.SystemAuthority.new(:ultracode_reactor)) do
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
        # Through the DurationBudget clock seam (default DateTime.utc_now/0)
        # so the whole lease-lifetime world -- TTL writes here, expiry
        # checks, and the budget boundary -- moves on ONE clock; identical
        # behavior in production, consistently fast-forwardable in tests.
        if DateTime.compare(expires_at, DurationBudget.now()) == :lt do
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
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(lease_token == ^lease_token)
    |> Ash.read_one(load: load)
  end

  # Preserve the canonical semantic subject and upstream receipt evidence in
  # every terminal lease receipt. This is evidence binding only; it never
  # changes verifier outcome or manufactures authority.
  defp bind_semantic_work_identity(%Epoch{run: %Run{} = run}, evidence) do
    required = [
      run.work_order_iri,
      run.checkpoint_iri,
      run.graph_digest,
      run.repository_identity,
      run.execution_repo_alias,
      run.base_sha
    ]

    if Enum.all?(required, &is_binary/1) do
      Map.put(evidence, "semantic_work", %{
        "work_order_iri" => run.work_order_iri,
        "checkpoint_iri" => run.checkpoint_iri,
        "graph_digest" => run.graph_digest,
        "repository_identity" => run.repository_identity,
        "execution_repo_alias" => run.execution_repo_alias,
        "execution_policy" => if(run.execution_policy, do: Atom.to_string(run.execution_policy)),
        "dependency_evidence" => run.dependency_evidence || %{},
        "base_sha" => run.base_sha
      })
    else
      evidence
    end
  end

  defp bind_semantic_work_identity(_epoch, evidence), do: evidence

  # ------------------------------------------------------------------
  # Closure verification
  # ------------------------------------------------------------------

  defp verified_outcome(%Epoch{} = epoch, final_head, claimed_outcome, evidence) do
    # `fabric_verifier` is fabric-owned evidence: a worker-supplied value under
    # that key is dropped, never merged, so it cannot spoof a passing court.
    evidence = Map.delete(evidence, "fabric_verifier")

    case worktree_head(epoch.worktree) do
      {:ok, ^final_head} ->
        fabric_verified(
          epoch,
          final_head,
          claimed_outcome,
          Map.put(evidence, "head_verified", true)
        )

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

  # Independent definition of done: when the Run names a registered verifier
  # suite and the worker claims an alive-family outcome, the FABRIC runs that
  # suite against the confirmed head (see `Xaas.Ultracode.Verifier` for the
  # threat model). pass keeps the claimed outcome (never upgrades it); fail is
  # falsified evidence (:build_broken); timeout/error is unverifiable
  # (:partial_alive). Other claimed outcomes have nothing to verify.
  defp fabric_verified(
         %Epoch{run: %Run{verifier_suite: suite}} = epoch,
         final_head,
         claimed_outcome,
         evidence
       )
       when is_binary(suite) and claimed_outcome in [:alive, :partial_alive] do
    {:ok, result} =
      Verifier.run(suite, %{
        worktree: epoch.worktree,
        head: final_head,
        run_id: epoch.run_id,
        epoch_id: epoch.id,
        executor: epoch.leased_to
      })

    evidence = Map.put(evidence, "fabric_verifier", result)

    case result["status"] do
      "pass" -> {claimed_outcome, evidence}
      "fail" -> {:build_broken, evidence}
      _unverifiable -> {:partial_alive, evidence}
    end
  end

  # Receipt law (Xaas.Ultracode.Validations.AliveRequiresCourt): :alive is
  # manufactured ONLY by a qualifying terminal court -- head_verified plus a
  # PASSING fabric verifier. A Run with NO registered verifier suite has no
  # court, so an :alive claim downgrades to :partial_alive BEFORE sealing:
  # the head was verified, but nothing independently verified the work. This
  # keeps `Lease.close/4` from ever tripping the sealing guard (which would
  # strand a completed epoch without its receipt), while keeping the sealed
  # vocabulary honest -- only a court-pass head can ever say :alive.
  defp fabric_verified(_epoch, _final_head, :alive, evidence) do
    {:partial_alive, Map.put(evidence, "verifier_suite_absent", true)}
  end

  defp fabric_verified(_epoch, _final_head, claimed_outcome, evidence),
    do: {claimed_outcome, evidence}

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
