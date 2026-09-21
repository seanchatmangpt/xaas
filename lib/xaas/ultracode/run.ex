defmodule Xaas.Ultracode.Run do
  @moduledoc """
  A bounded attempt at a goal, realized across ordered `Epoch`s.

  `state` is the Run-level lifecycle (`:pending | :running | :completed |
  :failed | :abandoned`); `standing` is the DfCM admitted/observed vocabulary
  (`:unknown | :admitted | :refused | :blocked`) from this repo's own
  CLAUDE.md doctrine (UNKNOWN|PARTIAL_ALIVE|ALIVE|BLOCKED|... +
  typed REFUSED), kept as its own attribute rather than overloaded onto
  `state` because the two questions ("what phase is this Run in" vs. "is
  this Run's claim admitted") are independent.

  `max_cycles` bounds the Run (no unbounded epoch generation); `cycle` is the
  Run's own next-cycle counter, advanced by whatever creates `Epoch` rows
  (not enforced here -- `Epoch.unique_run_cycle` is the hard constraint).

  ## `org_id` -- real, disclosed, NOT ENFORCED (see ADR-0002)

  Real investigation finding (docs/adr/0002-ultracode-org-scoping-seam.md):
  Ultracode (`Run`/`Epoch`; `Lease` owns no resource of its own -- see its
  own moduledoc) was the one unscoped seam in an otherwise org-scoped
  codebase. This repo has a real, established convention for org scoping
  (a plain `org_id, :string` attribute + a per-domain
  `Checks.ActorOrgMatches`-style `Ash.Policy.SimpleCheck` + `XaasWeb.Plugs.
  ResolveOrgActor` resolving a caller-asserted `X-Org-Id` header into an
  actor for `/api`'s `AshJsonApi.Router` routes -- see
  `Xaas.Platform.Checks.ActorOrgMatches` and that plug's own moduledoc for
  ~14 resources already wired this way).

  ### Real query-layer enforcement (this pass -- see also `Epoch`'s own
  ### moduledoc "Org scoping" section)

  The schema-only seam above is now REAL at the query layer: `multitenancy
  do strategy :attribute; attribute :org_id end` below (real Ash 3.33.1
  `:attribute` multitenancy -- verified against `deps/ash/lib/ash/
  resource/verifiers/validate_multitenancy.ex` and `deps/ash/documentation/
  topics/advanced/multitenancy.md`, not guessed) makes this resource's
  PRIMARY `:read` action (`defaults([:read])`) genuinely tenant-`:enforce`d
  -- Ash's real per-action default (`deps/ash/lib/ash/actions/read/
  read.ex:handle_multitenancy/1`, `case action_multitenancy do :enforce ->
  ... validate_multitenancy ... end`): a bare `Ash.get!(Run, id)` or
  `Ash.read!(Run)` with no tenant now raises
  `Ash.Error.Invalid.TenantRequired`, never silently returns another org's
  row. No resource-level `global? true` is set -- that flag would defeat
  `:enforce` for every action on the resource by short-circuiting
  `Ash.Resource.Info.multitenancy_global?/1`, which both
  `Ash.Actions.Helpers.validate_changeset_multitenancy/1` and
  `read.ex`'s own `validate_multitenancy/1` check ahead of the per-action
  setting.

  Every internal/system call site (`Xaas.Ultracode.Reactor`'s
  `:fetch_active_runs` step, `NextEpoch`, `MissedEpochs`) is instead
  routed through the `:read_unscoped` read action defined below
  (`multitenancy :allow_global` -- optional tenant, not ignored-if-present)
  -- deliberate and visible in the action list, never a silent
  resource-wide bypass. `:create`, `:advance_cycle`, `:transition_state`,
  `:start`, `:mark_expected_epoch`, and `:mark_completed_epoch` are each
  explicitly marked `multitenancy :allow_global` too, with the reason
  documented at each action: `:create` because it is called both from the
  customer-facing controller (which sets `org_id` explicitly from the
  authenticated org, never from a `set_tenant` call) and from every
  internal/test fixture with no org at all; the rest because they mutate
  an already-loaded Run struct from trusted internal code
  (`Xaas.Ultracode.NextEpoch`, test fixtures) and are never reachable from
  a customer-facing path.

  The one genuinely customer-facing, query-layer-enforced read this pass
  adds is `XaasWeb.ExecutionFabricController.receipts_for_org/3`, which
  now calls `Ash.get(Xaas.Ultracode.Epoch, epoch_id, tenant: org_id)` on
  Epoch's own `:enforce`d default `:read` (see that resource's moduledoc)
  -- a real `org_id == tenant` filter applied by Ash itself before the row
  ever reaches this controller, not a manual `if epoch.run.org_id ==
  org_id` comparison after the fact.

  That convention does not reach this resource's real HTTP surface.
  `Run`/`Epoch` have no `json_api do routes do ... end end` block at all --
  their only real HTTP surface is the custom `XaasWeb.ExecutionFabricController`
  under `/internal-api/execution/*`, gated by ONE shared `INTERNAL_API_TOKEN`
  Bearer token with no per-caller actor resolution wired to that router scope,
  and its MCP/hook tool schemas (`claim_next`, `admit_tool`, ...) carry no
  org-identifying field at all -- callers are keyed by the free-text
  `provider` string ("zcode", "opencode"), not by org. Every action
  currently defined on `Run`/`Epoch` is also either admitted only through
  the real `Xaas.Checks.SystemActor` system-authority predicate (the
  XAAS-2601/wave-4 mapping; see `policies do` below and `Epoch`'s own
  moduledoc) or denied by the resource's deny floor -- there are zero
  org-scoped policy clauses to extend today, and no real fact ("which org
  does this caller represent") reaches an Ultracode action to check.

  Applying the existing convention here verbatim would be real but
  functionally inert dead code (a check with nothing real to compare
  against on the only path that ever calls it) unless a NEW,
  undisclosed-anywhere mechanism for asserting org identity on the
  single-shared-token, provider-keyed execution fabric is also invented --
  out of scope per this task's own rule 6. `org_id` below is therefore the
  minimal real, disclosed, schema-only seam: a nullable string attribute,
  no enforcement, no policy change, so a real migration exists to build on
  without checking against a fact nothing yet supplies. See ADR-0002 for
  the full design note and what would need to land first.

  ## Duration budget (the 8-hour standing-wave law)

  A Run carries a real wall-clock DURATION BUDGET: `duration_budget_seconds`
  (default 28_800 = 8 hours, configurable per run) counted from `started_at`
  -- never reset, never restarted. The budget's single source of truth is
  `Xaas.Ultracode.DurationBudget` (`deadline/1`, `exhausted?/2`, `gate/2`,
  `drain_and_complete/2`); this resource carries the fields, the boundary
  calculation (`budget_deadline_at`), and the enforcement call sites:

    * the `:autonomic_wave` scheduler (the operator-ordered standing wave:
      capacity 5, continuous 30-minute waves) consults the budget BEFORE
      dispatching each wave: within budget -> dispatch and count the wave
      (`:record_wave`); past it -> NO new dispatch, in-flight work is
      drained (live leases finish, stale ones reaped per the existing
      `MissedEpochs` rule), and the session Run transitions to the terminal
      `:completed` with a final receipt (waves run, epochs
      terminal-counted, duration actual vs budget);
    * `Xaas.Ultracode.Lease.claim_next/3` excludes epochs of
      budget-exhausted Runs from ready work (the DB-enforced
      `budget_deadline_at > now` candidate filter -- a Run cannot keep
      claiming new leases past its budget);
    * `Xaas.Ultracode.NextEpoch` stops constructing new Epochs for an
      exhausted Run and completes it once its last epoch is terminal --
      an exhausted Run cannot silently keep cycling or sit `:running`
      forever.

  Resume semantics are the natural consequence of the law's shape: a
  stopped session (process down, waves paused) whose budget is not yet
  exhausted resumes on the next scheduler fire with its REMAINING budget,
  because `started_at` is written once by `:begin_wave_session` and never
  rewritten -- the budget is wall-clock from start, not from resume. A
  Run without `started_at` (never started; e.g. the per-item-attempt Runs
  the Autonomic loop creates directly with a `:running` Epoch) has no
  budget in force and keeps today's exact behavior.

  ## Scheduling (`oban do` block)

  Real `AshOban` (`~> 0.8`, pinned `0.8.14` per `mix.lock`) `scheduled_actions`
  usage -- the fourth real use in this repo, following the exact
  `scheduled_actions do schedule ... end` shape already proven in
  `Xaas.Operations.CapabilityLivenessReceipt` and
  `Xaas.Platform.WebhookDelivery` (see those moduledocs). Every minute, the
  generated `Xaas.Ultracode.Run.Workers.Tick` Oban worker calls the real
  `:tick` generic action below. The scheduler's ENTIRE job is Time -> Tick:
  the `:tick` action itself does nothing but invoke `Xaas.Ultracode.Reactor`
  (see that module for the real missed-epoch-transition workflow) -- no
  engineering-workflow logic lives in this resource or in AshOban's cron
  wiring.
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Ultracode,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban, AshRateLimiter]

  # The duration-budget law (`:autonomic_wave` scheduler gate below) --
  # module-level alias because the action DSL expands this resource's
  # blocks into generated functions, where a lexically-scoped alias
  # inside one block is dropped as unused.
  alias Xaas.Ultracode.DurationBudget

  postgres do
    table("ultracode_runs")
    repo(Xaas.Repo)
  end

  multitenancy do
    strategy(:attribute)
    attribute(:org_id)
  end

  # Real per-org quota on the customer-facing submission surface (2026-09
  # fs-safety hardening pass): before this, POST
  # /internal-api/execution/runs had zero rate limit or quota -- confirmed
  # by a real scripted loop against the dev DB (200/200 Run creates
  # succeeded in ~0.3s with zero rejection), not guessed. `Xaas.Hammer`
  # (ETS-backed `Hammer`) + `AshRateLimiter` is this repo's own existing,
  # idiomatic pattern for exactly this shape --
  # `Xaas.Billing.ApprovalPricingOverride`'s `rate_limit do` block is the
  # only other real usage, throttling its own `:create` at 5/min/requester.
  # Scoped to the `:submit` action ONLY (see below), never the shared
  # `:create` action every internal/test call site also uses -- rate
  # limiting `:create` itself would have made this same Hammer ETS bucket
  # shared (and falsely exhausted) across every unrelated test file's own
  # `Run.create` calls within one `mix test` run, a real regression this
  # design avoids by construction rather than by a higher limit.
  rate_limit do
    backend(Xaas.Hammer)

    action(:submit,
      limit: 30,
      per: :timer.minutes(1),
      key: fn changeset, _context ->
        org_id = Ash.Changeset.get_attribute(changeset, :org_id) || "unscoped"
        "ultracode_run:submit:#{org_id}"
      end
    )
  end

  oban do
    scheduled_actions do
      schedule :tick, "* * * * *" do
        action(:tick)
        worker_module_name(Xaas.Ultracode.Run.Workers.Tick)

        # XAAS-2601: the cron worker runs `:tick` THROUGH authorization
        # (`config :ash_oban, :authorize?` defaults true) with no stored
        # actor, so the policy below would refuse it unless the schedule
        # itself supplies the real system authority actor. This is the
        # AshOban-documented `default_actor` "system-actor flow" -- the
        # scheduler's own authority, made explicit instead of a bypass.
        default_actor(%Xaas.SystemAuthority{service: :oban_scheduler})

        # Explicit `:default` queue -- `config :xaas, Oban` (config.exs)
        # only lists `queues: [default: 10]`. AshOban's own default queue
        # name for a scheduled action is the resource's short name plus
        # the schedule name (e.g. `run_tick`), which this repo's Oban
        # config does not list as a runnable queue -- an unlisted queue's
        # jobs are enqueued but never processed. Pinning `:default` here
        # keeps this scheduled action real/running rather than silently
        # dormant.
        queue(:default)
      end

      # DfCM composition: keep item construction parallel while serializing
      # the shared integration/promote phase. The action itself owns no
      # additional authority; it only invokes the existing Autonomic loop.
      schedule :autonomic_wave, "*/30 * * * *" do
        action(:autonomic_wave)
        worker_module_name(Xaas.Ultracode.Run.Workers.AutonomicWave)
        queue(:ultracode_wave)

        # Wave-4 authority tightening (completing XAAS-2601/2602): the cron
        # worker runs `:autonomic_wave` THROUGH authorization with the
        # scheduler's own real system authority -- the same AshOban
        # `default_actor` system-actor flow `:tick` uses. The action's
        # previous `authorize_if(always())` bypass is deleted; the action
        # is a canonical `Xaas.Checks.SystemActor` subject bound to
        # `:oban_scheduler`.
        default_actor(%Xaas.SystemAuthority{service: :oban_scheduler})
      end

      # Semantic work is selected upstream; this clock dispatches already
      # materialized :autonomic_wave_attempt Epochs. It shares the one-slot
      # queue with the legacy APS wave so shared controller waves never overlap.
      #
      # WATCHDOG DEMOTION (wave-6 event-driven law): the PRIMARY dispatch
      # clock is now the event path -- `Xaas.Ultracode.SemanticWaveTrigger`
      # enqueues a deduplicated wave job the moment an admitted frontier
      # transition materializes (transactionally with the ready Epoch).
      # This */30 cron remains ONLY as the watchdog for missed events: on
      # fire it dispatches whatever un-dispatched wave-ready Epoch exists
      # (a lost/failed event-path job), else it is an IDLE no-op receipt.
      schedule :semantic_wave, "*/30 * * * *" do
        action(:semantic_wave)
        worker_module_name(Xaas.Ultracode.Run.Workers.SemanticWave)
        queue(:ultracode_wave)

        # Wave-4 authority tightening: same `default_actor` system-actor
        # flow as `:autonomic_wave` above -- the scheduler's own admitted
        # `:oban_scheduler` authority replaces the deleted
        # `authorize_if(always())` bypass.
        default_actor(%Xaas.SystemAuthority{service: :oban_scheduler})
      end

      # The CONTINUOUS engine cadence (every 5 minutes) -- the between-waves
      # half of the loop: reap stale epochs, fill free worker slots up to the
      # provider pool capacity (5 in production config), advance
      # completed/stalled epochs, and carry the tick-health verdict in its
      # report. All logic lives in `Xaas.Ultracode.Engine`; this schedule is
      # only Time -> Cycle, exactly like `:tick` and `:autonomic_wave`.
      # Single-slot dedicated queue (`ultracode_engine: 1` in
      # `config :xaas, Oban`) for the same serialization reason as
      # `:ultracode_wave`: engine cycles are capacity-filling work whose
      # slot accounting must never overlap itself.
      schedule :engine_cycle, "*/5 * * * *" do
        action(:engine_cycle)
        worker_module_name(Xaas.Ultracode.Run.Workers.EngineCycle)

        # XAAS-2601 system-actor flow, same as `:tick` above: the cron
        # worker runs through authorization with no stored actor, so the
        # scheduler's own authority is made explicit. (The engine's INTERNAL
        # mutations -- epoch reaping, receipt sealing -- each carry the
        # admitted `:ultracode_reactor` service directly, matching the
        # `Xaas.Checks.SystemActor` capability map for those subjects.)
        default_actor(%Xaas.SystemAuthority{service: :oban_scheduler})

        queue(:ultracode_engine)
      end
    end
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    # XAAS-2601 + wave-4 authority tightening: EVERY internal-only Run
    # mutation is admitted by the REAL system authority predicate instead
    # of the previous action-wide `authorize_if(always())` bypasses --
    # which any caller through the normal authorization path satisfied.
    #
    #   * `:tick` (cron) and the three schedule clocks `:autonomic_wave`/
    #     `:semantic_wave`/`:engine_cycle` carry the `:oban_scheduler`
    #     service (each schedule supplies it via AshOban `default_actor`);
    #   * `:begin_wave_session`/`:record_wave` -- the duration-budget
    #     bookkeeping the wave clock drives -- carry `:oban_scheduler`;
    #   * `:advance_cycle`/`:transition_state` (the Ultracode Reactor
    #     pipeline) and `:stop`/`:resume` (the engine kernel's lifecycle
    #     recovery, `:running -> :abandoned` with lease revocation and the
    #     `:abandoned -> :running` re-arm guarded by `RunTransitionAllowed`/
    #     `RunResumable`) carry the `:ultracode_reactor` service.
    #
    # None of these actions accepts a caller-supplied subject or authority,
    # and none is a public DO surface: an ambient/ordinary actor now falls
    # through to the deny floor below. Real call sites pass the admitted
    # actor explicitly (the schedule `default_actor`s, `Xaas.SystemAuthority`
    # at the reactor/engine call sites) or are kernel paths that opt out of
    # authorization explicitly (`authorize?: false`), so the tightening is
    # behavior-preserving for every admitted caller while no longer
    # admitting everything else.
    bypass action([
             :tick,
             :advance_cycle,
             :transition_state,
             :autonomic_wave,
             :semantic_wave,
             :engine_cycle,
             :begin_wave_session,
             :record_wave,
             :stop,
             :resume
           ]) do
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    # Duration-budget scheduler internals (postdating the XAAS-2601
    # classification): `:begin_wave_session` (writes started_at ONCE from
    # the law clock) and `:record_wave` (counts one dispatched wave) are
    # wave-session ledger mutations on the session Run -- classified above
    # with the `:oban_scheduler` service they belong to.

    policy always() do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    # Real, deliberately global internal/system read action -- see the
    # moduledoc's "Real query-layer enforcement" section. `:allow_global`,
    # not `:bypass`: a supplied tenant still filters; every real caller
    # today (`Xaas.Ultracode.Reactor`, `NextEpoch`, `MissedEpochs`) passes
    # none, so this behaves exactly like the old, pre-retrofit unscoped
    # default `:read`.
    read :read_unscoped do
      multitenancy(:allow_global)
    end

    create :create do
      accept([
        :goal,
        :deadline_at,
        :max_cycles,
        :epoch_timeout_seconds,
        :provider,
        :org_id,
        :verifier_suite,
        :duration_budget_seconds,
        :work_order_iri,
        :checkpoint_iri,
        :graph_digest,
        :repository_identity,
        :execution_repo_alias,
        :execution_policy,
        :dependency_evidence,
        :court_map,
        :base_sha
      ])

      # `:allow_global`: called both from the customer-facing controller
      # (`org_id` set explicitly from the authenticated org -- see this
      # module's own moduledoc) and from every internal/test fixture with
      # no org and no tenant at all. `:enforce` (the default once
      # `multitenancy do ... end` is configured) would raise
      # `TenantRequired` on every one of those real internal callers.
      validate({Xaas.Ultracode.Validations.VerifierSuiteRegistered, []})

      multitenancy(:allow_global)
    end

    # Real, customer-facing submission action (2026-09 fs-safety hardening
    # pass) -- identical accept list/multitenancy to `:create` above, kept
    # as a SEPARATE action purely so the `rate_limit do` block above can
    # target the one real HTTP entry point
    # (`XaasWeb.ExecutionFabricController.create_run_row/3`) without also
    # throttling `:create`, which this resource's own extensive internal
    # test suite (and `Xaas.Ultracode.Reactor`/`NextEpoch`/`MissedEpochs`
    # fixtures) call directly and far more than 30 times/minute in a fast
    # `mix test` run.
    create :submit do
      accept([
        :goal,
        :deadline_at,
        :max_cycles,
        :epoch_timeout_seconds,
        :provider,
        :org_id,
        :verifier_suite,
        :duration_budget_seconds
      ])

      validate({Xaas.Ultracode.Validations.VerifierSuiteRegistered, []})

      multitenancy(:allow_global)
    end

    # Every plain `update` action below is `multitenancy(:bypass)`, NOT
    # `:allow_global` -- a real, evidence-based distinction (a failing
    # `mix test` run, not guessed): Ash 3.33.1's UPDATE pipeline has a
    # SECOND, later tenant checkpoint independent of the one
    # `handle_multitenancy/2` runs at action-dispatch time -- see `Epoch`'s
    # own `actions do` block for the full explanation (verified against
    # `deps/ash/lib/ash/actions/update/update.ex`'s private `set_tenant/1`,
    # whose guard omits `:allow_global` unlike CREATE's equivalent). This
    # behaves identically to `:allow_global` for every real caller here
    # (none ever pass a tenant).
    update :advance_cycle do
      accept([])
      change(increment(:cycle))

      multitenancy(:bypass)
    end

    update :mark_expected_epoch do
      accept([:last_expected_epoch_at])

      multitenancy(:bypass)
    end

    update :mark_completed_epoch do
      accept([:last_completed_epoch_at])

      multitenancy(:bypass)
    end

    update :transition_state do
      accept([:state, :standing])
      require_atomic?(false)

      validate({Xaas.Ultracode.Validations.RunTransitionAllowed, []})

      # Terminal-only: sets `terminal_at` iff the destination state closes
      # the Run (`:completed`/`:failed`/`:abandoned`) -- see the change's
      # own moduledoc and the `terminal_at` attribute doc.
      change(Xaas.Ultracode.Changes.SetTerminalAt)

      multitenancy(:bypass)
    end

    # Real admitted action closing ULTRACODE-50 blocker (2): the ONE path
    # that transitions a fresh `Run` from `:pending` to `:running` AND
    # constructs its very first `Epoch` (cycle 0). Refuses (does not
    # silently no-op) if the Run is not `:pending` -- calling `:start`
    # twice, or on an already-`:running`/`:completed` Run, is a real
    # error, not an idempotent skip, matching this repo's typed-refusal
    # convention rather than papering over a caller mistake.
    update :start do
      accept([])
      require_atomic?(false)

      argument :exact_subject, :string do
        allow_nil?(false)
      end

      # Optional exact-SHA worktree already provisioned by the caller's
      # admitted materialization path. Carrying it here lets every semantic
      # policy use the single Run.:start -> CreateFirstEpoch lifecycle.
      argument :worktree, :string do
        allow_nil?(true)
      end

      validate({Xaas.Ultracode.Validations.RunIsPending, []})

      change(set_attribute(:state, :running))
      # Through the DurationBudget clock seam (default DateTime.utc_now/0)
      # -- identical behavior today, injectable in tests, and the one
      # place `started_at` is written so the duration budget's wall-clock
      # anchor has a single source of truth.
      change(set_attribute(:started_at, &Xaas.Ultracode.DurationBudget.now/0))
      change(increment(:cycle))
      change(Xaas.Ultracode.Changes.CreateFirstEpoch)

      multitenancy(:bypass)
    end

    # Real admitted action beginning the operator-ordered standing wave
    # session (the 8-hour run: capacity 5, continuous 30-minute waves --
    # see the moduledoc "Duration budget" section). Marks the Run as THE
    # wave session (`wave_session: true`) and writes `started_at` ONCE,
    # from the DurationBudget clock seam: the budget is wall-clock from
    # this instant, never reset by a later resume. Refuses (typed, not a
    # silent no-op) if the Run is not `:pending` -- same discipline as
    # `:start` above. The scheduler (`:autonomic_wave`) calls this
    # implicitly on the first fire via DurationBudget.find_or_begin...;
    # it is also the operator's explicit one-call way to materialize the
    # standing-wave order.
    update :begin_wave_session do
      accept([])
      require_atomic?(false)

      validate({Xaas.Ultracode.Validations.RunIsPending, []})

      change(set_attribute(:state, :running))
      change(set_attribute(:wave_session, true))
      change(set_attribute(:started_at, &Xaas.Ultracode.DurationBudget.now/0))

      multitenancy(:bypass)
    end

    # Real admitted action counting one dispatched wave on the session
    # Run (`Xaas.Ultracode.DurationBudget`'s scheduler gate calls it after
    # a wave actually ran; the count is what the final receipt reports as
    # "waves run"). Waves, not epoch cycles -- the session Run owns no
    # Epochs, so `:advance_cycle`'s cycle counter would be a semantic
    # overload; this is the explicit, dedicated ledger.
    update :record_wave do
      accept([])
      change(increment(:waves_run))

      multitenancy(:bypass)
    end

    # Real generic action -- the sole body of the AshOban `:tick`
    # scheduled action above. Deliberately NOT an update/create action on
    # a single Run row: a tick advances every `:running` Run at once, so
    # (matching `Xaas.Platform.WebhookDelivery`'s `:retry_failed_deliveries`
    # generic-action convention exactly) this is `action :tick, :map do run
    # fn ... end end`, not a per-record action. All engineering-workflow
    # logic lives in `Xaas.Ultracode.Reactor`/`Xaas.Ultracode.MissedEpochs`
    # -- this action is only the call site.
    action :tick, :map do
      run(fn _input, _context ->
        case Reactor.run(Xaas.Ultracode.Reactor) do
          {:ok, result} -> {:ok, %{advanced: result}}
          {:error, error} -> {:error, error}
        end
      end)
    end

    # Real generic action -- the sole body of the AshOban `:autonomic_wave`
    # scheduled action above (every 30 minutes), mirroring `:tick` exactly:
    # a generic action, all engineering-workflow logic in
    # `Xaas.Ultracode.Autonomic` and `Xaas.Ultracode.DurationBudget`, this
    # action only the call site. The one knob the schedule carries is the
    # worker capacity -- 5 concurrent leased workers (subagents) per wave,
    # the operator-ordered standing wave size -- every other default is
    # `Autonomic`'s own. Five construction workers may run in parallel
    # inside one wave; the dedicated one-slot Oban queue prevents two waves
    # from racing the shared promotion/integration phase. The loop is
    # itself receipt-bearing (ndjson ledger plus the JSON receipt written
    # beside it) and human_inputs is 0 by construction. `Autonomic.run/1`
    # is synchronous on purpose: the AshOban worker runs it to completion
    # inside the single-slot `:ultracode_wave` queue, so the loop's own
    # repair/promote lifecycle (including its serialized `--no-ff`
    # integration merges) never overlaps another wave. The runner is read
    # through an application-env seam purely so the qualification test can
    # capture the call without reaching the real subprocess dispatcher.
    #
    # Duration budget (the operator's "keep a 5 agent loop running for 8
    # hours" order, materialized): every fire resolves the standing-wave
    # session Run (`DurationBudget.find_or_begin_wave_session/1` -- the
    # FIRST fire begins it and starts the wall clock; later fires find it,
    # including after a restart, which is the resume path), then gates on
    # its budget BEFORE dispatching:
    #
    #   * `:allow` -> the wave runs at capacity 5 and is counted
    #     (`:record_wave`);
    #   * `{:refuse, :budget_exhausted}` -> NO new dispatch, ever; the
    #     session is drained (live leases finish, stale ones reaped per
    #     the existing `MissedEpochs` rule), transitioned to terminal
    #     `:completed`, and the final receipt (waves run, epochs
    #     terminal-counted, duration actual vs budget) is returned -- and
    #     persisted beside the ledger when a ticket dir is configured.
    #     Until every in-flight worker is truly terminal the session
    #     reports `draining` instead of silently claiming completion.
    action :autonomic_wave, :map do
      run(fn _input, _context ->
        now = DurationBudget.now()

        case DurationBudget.find_or_begin_wave_session(now: now) do
          {:ok, session, _phase} ->
            case DurationBudget.gate(session, now) do
              :allow ->
                runner =
                  Application.get_env(:xaas, :ultracode_wave_runner, {
                    Xaas.Ultracode.Autonomic,
                    :run
                  })

                result =
                  case runner do
                    {mod, fun} when is_atom(mod) and is_atom(fun) ->
                      apply(mod, fun, [[capacity: 5]])

                    fun when is_function(fun, 1) ->
                      fun.(capacity: 5)
                  end

                case result do
                  {:ok, report} ->
                    {:ok, recorded} = DurationBudget.record_wave(session)

                    {:ok,
                     %{
                       standing: report["standing"],
                       receipt: report["receipt_path"],
                       budget: %{
                         run_id: session.id,
                         dispatch: :allowed,
                         waves_run: recorded.waves_run,
                         budget_seconds: session.duration_budget_seconds,
                         remaining_seconds: DurationBudget.remaining_seconds(session, now)
                       }
                     }}

                  {:error, error} ->
                    {:error, error}
                end

              # The one law-critical branch: past the boundary the ONLY
              # allowed actions are drain, terminal transition, receipt.
              {:refuse, :budget_exhausted, _details} ->
                case DurationBudget.drain_and_complete(session, now: now) do
                  {:ok, %{run: run, receipt: receipt}} ->
                    {:ok,
                     %{
                       standing: "REFUSED_BUDGET_EXHAUSTED",
                       receipt: receipt["receipt_path"],
                       budget: %{
                         run_id: run.id,
                         dispatch: :budget_exhausted,
                         waves_run: run.waves_run,
                         budget_seconds: run.duration_budget_seconds,
                         remaining_seconds: 0,
                         session_state: to_string(run.state),
                         draining: false,
                         receipt: receipt
                       }
                     }}

                  {:error, {:draining, info}} ->
                    # Never claim completion over live in-flight workers;
                    # also never dispatch. The next fire (or tick) finishes
                    # the drain.
                    {:ok,
                     %{
                       standing: "REFUSED_BUDGET_EXHAUSTED",
                       receipt: nil,
                       budget:
                         Map.merge(info, %{
                           dispatch: :budget_exhausted,
                           draining: true
                         })
                     }}
                end
            end

          # The 8-hour run already completed and re-arm is off: the
          # operator's order was "waves for exactly 8 hours, THEN STOP
          # DISPATCHING" -- so this fire dispatches nothing and reports
          # the completed session's receipt.
          {:refuse, :standing_wave_completed, session} ->
            receipt = DurationBudget.final_receipt(session, now)

            {:ok,
             %{
               standing: "REFUSED_BUDGET_EXHAUSTED",
               receipt: receipt["receipt_path"],
               budget: %{
                 run_id: session.id,
                 dispatch: :stopped_after_budget,
                 waves_run: session.waves_run,
                 budget_seconds: session.duration_budget_seconds,
                 remaining_seconds: 0,
                 session_state: to_string(session.state),
                 receipt: receipt
               }
             }}

          {:error, reason} ->
            {:error, reason}
        end
      end)
    end

    # Separate scheduler call site for semantic work: the WATCHDOG half of
    # the event-driven dispatch law (wave-6). The primary clock is
    # `Xaas.Ultracode.SemanticWaveTrigger`, which enqueues the same
    # `:semantic_wave` action immediately (same `:ultracode_wave` queue,
    # same `:oban_scheduler` authority) on every admitted frontier
    # transition that materializes wave-attempt work. This cron fire only
    # needs to catch a MISSED event: dispatch any ready wave Epoch that
    # the event path did not reach (a lost job), else report IDLE --
    # the no-op watchdog case. SemanticWave itself cannot lease, verify,
    # or crown work.
    action :semantic_wave, :map do
      run(fn _input, _context ->
        runner =
          Application.get_env(
            :xaas,
            :ultracode_semantic_wave_runner,
            {Xaas.Ultracode.SemanticWave, :run}
          )

        result =
          case runner do
            {mod, fun} when is_atom(mod) and is_atom(fun) -> apply(mod, fun, [[capacity: 5]])
            fun when is_function(fun, 1) -> fun.(capacity: 5)
          end

        case result do
          {:ok, report} -> {:ok, %{status: report["status"], receipt: report["receipt_path"]}}
          {:error, error} -> {:error, error}
        end
      end)
    end

    # Real generic action -- the sole body of the AshOban `:engine_cycle`
    # scheduled action (every 5 minutes), mirroring `:tick`/`:autonomic_wave`
    # exactly: all engineering-workflow logic in `Xaas.Ultracode.Engine`
    # (reap -> fill worker slots at pool capacity -> advance -> health),
    # this action only the call site. The runner is read through an
    # application-env seam so tests can capture/inject without reaching the
    # real engine, same as the wave runner above.
    action :engine_cycle, :map do
      run(fn _input, _context ->
        runner =
          Application.get_env(:xaas, :ultracode_engine_runner, {Xaas.Ultracode.Engine, :cycle})

        result =
          case runner do
            {mod, fun} when is_atom(mod) and is_atom(fun) -> apply(mod, fun, [[]])
            fun when is_function(fun, 1) -> fun.([])
          end

        case result do
          {:ok, report} -> {:ok, report}
          %{} = report -> {:ok, report}
          {:error, error} -> {:error, error}
        end
      end)
    end

    # Operator-facing STOP: `:running -> :abandoned` (edge already
    # allow-listed by `RunTransitionAllowed`), standing `:blocked` -- the
    # work stopped mid-flight, which is exactly what `:blocked` means in
    # this repo's standing vocabulary. The after-action
    # (`Changes.RevokeLiveLeases`) refuses every LIVE lease this Run's
    # epochs hold -- a stopped run's in-flight workers get the typed
    # `:run_stopped` refusal and their own `:refused` receipts, so the
    # epoch lifecycle still holds its `terminal => receipt` invariant
    # after a stop. `:expected` (never-claimed) epochs are deliberately
    # left frozen: a stopped Run is out of the tick's active set, so
    # nothing advances them; a later `:resume` lets the normal missed/next
    # machinery dispose of them lawfully.
    update :stop do
      accept([])
      require_atomic?(false)

      change(set_attribute(:state, :abandoned))
      change(set_attribute(:standing, :blocked))
      # `:abandoned` is terminal -- persists the closing moment (`terminal_at`,
      # the egress's `run_abandoned` event time) via the same conditional
      # change `:transition_state` uses.
      change(Xaas.Ultracode.Changes.SetTerminalAt)
      change(Xaas.Ultracode.Changes.RevokeLiveLeases)

      validate({Xaas.Ultracode.Validations.RunTransitionAllowed, []})

      multitenancy(:bypass)
    end

    # Operator-facing RESUME: `:abandoned -> :running` re-arm. Standing
    # resets to `:unknown` (a resumed run has observed nothing since it
    # stopped -- old standing must not masquerade as current). No epoch is
    # constructed here: the tick machinery owns epoch construction, and on
    # the next ticks it disposes of whatever the stop froze (stale
    # `:expected` epochs go `:missed` with receipts; `NextEpoch`'s bounded
    # stale recovery advances the Run). `RunResumable` refuses the
    # degenerate case -- a Run with no cycles left and no live epoch -- as
    # a typed error instead of letting the next tick immediately fail it.
    update :resume do
      accept([])
      require_atomic?(false)

      change(set_attribute(:state, :running))
      change(set_attribute(:standing, :unknown))

      validate({Xaas.Ultracode.Validations.RunTransitionAllowed, []})
      validate({Xaas.Ultracode.Validations.RunResumable, []})

      multitenancy(:bypass)
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Real fs-safety bound (2026-09 hardening pass): before this,
    # `goal` was a genuinely unbounded string -- confirmed via a real
    # repro against the dev DB (a 5,000,000-byte goal was accepted with
    # zero rejection). `goal` is exactly the text handed to an LLM worker
    # as its instructions (see `Xaas.Ultracode.Lease`'s `claim_next/2`),
    # so it is real prose, never a blob -- 50,000 characters is generous
    # for any real goal description (tens of pages) while bounding the
    # unattended-growth/storage-exhaustion case a customer-facing
    # submission surface must not leave open.
    attribute :goal, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 50_000)
    end

    # Actuation provider lane: nil (default) keeps legacy reactor-driven
    # semantics (a `:running` Epoch completes next cycle); a provider id
    # ("zcode", "opencode", ...) switches this Run to provider-pull
    # semantics -- Epochs lease out to provider workers and complete only
    # on verified provider evidence. This is the fact EpochReactor's :plan
    # branches on.
    attribute :provider, :string do
      public?(true)
    end

    # Name of an operator-registered verifier suite
    # (`config :xaas, :ultracode_verifier_suites`) that the FABRIC runs at
    # close time against the worker's claimed head -- the independent
    # definition of done (`Xaas.Ultracode.Verifier`). A NAME only, never a
    # command: `VerifierSuiteRegistered` refuses anything unregistered, and a
    # suite only ever executes in a worktree under the operator containment
    # root. nil = no fabric verifier (today's behavior).
    attribute :verifier_suite, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 64, match: ~r/^[a-z0-9][a-z0-9_-]*$/)
    end

    # Canonical semantic-work identity. These fields are descriptive evidence
    # only. repository_identity names the semantic repository; execution_repo_alias
    # is the operator-local Worktrees lookup key. They are intentionally distinct.
    attribute :work_order_iri, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 1024)
    end

    attribute :checkpoint_iri, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 1024)
    end

    attribute :graph_digest, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 128)
    end

    attribute :repository_identity, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 512)
    end

    attribute :execution_repo_alias, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 128)
    end

    # Explicit policy makes the pre-existing lifecycle variation semantic:
    # continuous work waits for the tick clock; wave attempts are started
    # immediately but still use the same Run.:start first-Epoch path.
    attribute :execution_policy, :atom do
      allow_nil?(true)
      public?(true)
      constraints(one_of: [:continuous_epoch_run, :autonomic_wave_attempt])
    end

    # Typed upstream receipt identities/digests projected from the canonical
    # work graph. This is evidence carried by the Run, never authority.
    attribute :dependency_evidence, :map do
      allow_nil?(false)
      default(%{})
      public?(true)
    end

    # The fabric court-receipt contract (`Xaas.Ultracode.CourtReceipt`):
    # the work order's minted acceptance/falsifier/court IRIs mapped to the
    # one machine-checkable predicate each. Carried here from the execution
    # descriptor at materialization and consumed ONLY by the fabric at
    # close time, so the sealed receipt's acceptance_results /
    # falsifier_results / court_results are keyed by the work order's own
    # IRIs without the worker ever supplying them (`Lease.close/4` drops
    # worker-supplied copies before merging the fabric-computed ones).
    # nil = no court receipt contract (suite runs plain, today's behavior).
    attribute :court_map, :map do
      allow_nil?(true)
      public?(true)
    end

    attribute :base_sha, :string do
      allow_nil?(true)
      public?(true)
      constraints(match: ~r/^[0-9a-f]{40}$/)
    end

    # Real, disclosed, schema-only seam -- see this module's own moduledoc
    # ("org_id -- real, disclosed, NOT ENFORCED") and ADR-0002. Nullable,
    # unenforced: no policy or check reads this attribute today. It exists
    # so a real org-provenance value can start being recorded now, without
    # fabricating enforcement logic that has nothing real to check against
    # on Ultracode's actual (single-shared-token, provider-keyed) HTTP
    # surface.
    attribute :org_id, :string do
      public?(true)
    end

    attribute :state, :atom do
      allow_nil?(false)
      default(:pending)
      constraints(one_of: [:pending, :running, :completed, :failed, :abandoned])
      public?(true)
    end

    attribute :standing, :atom do
      allow_nil?(false)
      default(:unknown)
      constraints(one_of: [:unknown, :admitted, :refused, :blocked])
      public?(true)
    end

    attribute :started_at, :utc_datetime_usec do
      public?(true)
    end

    # The terminal-transition moment: written when this Run closes into
    # `:completed`/`:failed`/`:abandoned` (via `:transition_state` or
    # `:stop`, through `Changes.SetTerminalAt`; `:resume` and the
    # `{:pending, :running}` edge never write it). The OCEL egress uses
    # this as the `run_completed`/`run_failed`/`run_abandoned` event time
    # -- a dedicated persisted fact replacing the former `updated_at`
    # approximation. Nullable: a Run that never closed (and rows predating
    # the column) emits no terminal event rather than a fabricated time.
    attribute :terminal_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :deadline_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :cycle, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute :max_cycles, :integer do
      allow_nil?(false)
      default(1)
      public?(true)
    end

    # Configurable missed-epoch threshold, consumed by
    # `Xaas.Ultracode.MissedEpochs.advance_run/1`: an `Epoch` whose
    # `expected_at` is older than `now - epoch_timeout_seconds` and still
    # `:expected`/`:running` is transitioned to `:missed`. Real per-Run
    # config, not a hardcoded module attribute -- different Runs can carry
    # different tolerance for a missed cycle. 900s default: a provider-owned
    # (zcode/GLM) worker's claim->edit->close round trip outran 300s in a
    # real failover trial and the epoch was marked :missed mid-lease.
    attribute :epoch_timeout_seconds, :integer do
      allow_nil?(false)
      default(900)
      public?(true)
    end

    attribute :last_expected_epoch_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :last_completed_epoch_at, :utc_datetime_usec do
      public?(true)
    end

    # ------------------------------------------------------------------
    # Duration budget (the 8-hour standing-wave law -- see the moduledoc
    # section of the same name and `Xaas.Ultracode.DurationBudget`, the
    # law's single source of truth).
    # ------------------------------------------------------------------

    # Wall-clock budget in seconds, counted from `started_at` (written
    # once by `:start`/`:begin_wave_session` and never rewritten -- the
    # budget is from start, not from resume). 28_800 = the operator's
    # 8-hour order for the standing wave; per-run configurable. A Run
    # with `started_at: nil` has no budget in force (today's behavior).
    attribute :duration_budget_seconds, :integer do
      allow_nil?(false)
      default(28_800)
      constraints(min: 1)
      public?(true)
    end

    # Waves actually dispatched for this Run -- the standing-wave
    # session's count, incremented by `:record_wave` after each real wave
    # returns ok. What the final receipt reports as "waves run". (Epoch
    # cycles are `cycle`'s ledger; waves are this one's -- the two are
    # deliberately separate ledgers for separate questions.)
    attribute :waves_run, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    # Marks THE standing-wave session Run (at most one `:running` at a
    # time by scheduler discipline; the `:autonomic_wave` action finds it
    # by this flag). Plain `false` on every ordinary Run so the tick
    # machinery's `state == :running` scans treat a session exactly like
    # today's epoch-less Runs (a real no-op) -- no scan-site filters were
    # touched to introduce sessions.
    attribute :wave_session, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  calculations do
    # The budget boundary as ONE DB-computable statement:
    # `started_at + duration_budget_seconds` (nil when never started --
    # no budget in force). An expression calculation, not runtime, so
    # `Xaas.Ultracode.Lease.claim_next/3`'s ready-work candidate query
    # can enforce `is_nil(budget_deadline_at) or budget_deadline_at > now`
    # inside the database (an exhausted Run's epochs are not ready work),
    # and so the same boundary the pure law (`DurationBudget.deadline/1`)
    # computes in Elixir is the boundary the DB filters on -- one law,
    # two provably-identical statements, no drift.
    calculate :budget_deadline_at, :utc_datetime_usec do
      public?(true)

      calculation(
        expr(
          type(
            fragment("? + (? * interval '1 second')", started_at, duration_budget_seconds),
            :utc_datetime_usec
          )
        )
      )
    end
  end

  relationships do
    # `read_action: :read_unscoped` on both relationships below -- real,
    # deliberate: relationship loading inherits the LOADING query's tenant
    # (`deps/ash/lib/ash/actions/read/relationships.ex`), never the loaded
    # Run's own attribute, so `Xaas.Ultracode.Reactor`'s tenant-less
    # `Ash.load!(active_runs, :active_epoch)` would otherwise hit Epoch's
    # now tenant-`:enforce`d default `:read` and raise. Pinned to Epoch's
    # own `:read_unscoped` action so these loads behave exactly as they did
    # before this retrofit.
    has_many :epochs, Xaas.Ultracode.Epoch do
      read_action(:read_unscoped)
    end

    # Real, single source of truth for "this Run's current active Epoch" --
    # previously hand-rolled independently in both
    # `Xaas.Ultracode.Reactor.active_epoch_id/1` and
    # `Xaas.Ultracode.NextEpoch.advance_run/1`'s `has_active?` check, two
    # separate copies of the identical business predicate. `sort` is
    # required, not optional: no DB-level unique index covers
    # `[:expected, :running]` jointly (only `state == :running`, via
    # `Xaas.Ultracode.Validations.AtMostOneActiveEpoch`), so without a
    # deterministic tiebreak `has_one` would pick an arbitrary row under a
    # latent data anomaly.
    has_one :active_epoch, Xaas.Ultracode.Epoch do
      filter(expr(state in [:expected, :running]))
      sort(cycle: :desc)
      read_action(:read_unscoped)
    end
  end
end
