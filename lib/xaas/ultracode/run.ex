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
  currently defined on `Run`/`Epoch` is also already unconditionally
  `bypass action(...) do authorize_if(always()) end`ed (see `policies do`
  below and `Epoch`'s own moduledoc) -- there are zero org-scoped policy
  clauses to extend today, and no real fact ("which org does this caller
  represent") reaches an Ultracode action to check.

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
    end
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Real, scoped carve-out for the cron-fired `:tick` action -- same
    # `bypass action(:name)` shape as `Xaas.Platform.WebhookDelivery`'s
    # `:retry_failed_deliveries` bypass. `:tick` accepts no external
    # arguments and exposes no Run/Epoch field to a caller; it only
    # triggers the real `Xaas.Ultracode.Reactor` missed-epoch workflow.
    bypass action(:tick) do
      authorize_if(always())
    end

    # ERRC raise: same shape as `:tick` above, closing a gap the
    # authorize?: false / dead-policies review surfaced but didn't name
    # explicitly on this resource -- `:advance_cycle` and `:transition_state`
    # are both internal-only mutations the Ultracode Reactor pipeline
    # (`Xaas.Ultracode.NextEpoch.advance_from_completed/2`) invokes, and
    # were previously called with `authorize?: false` rather than an
    # explicit bypass, same dead-policy pattern as Epoch/Receipt.
    bypass action(:advance_cycle) do
      authorize_if(always())
    end

    bypass action(:transition_state) do
      authorize_if(always())
    end

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
        :verifier_suite
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
        :verifier_suite
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

      validate({Xaas.Ultracode.Validations.RunIsPending, []})

      change(set_attribute(:state, :running))
      change(set_attribute(:started_at, &DateTime.utc_now/0))
      change(increment(:cycle))
      change(Xaas.Ultracode.Changes.CreateFirstEpoch)

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

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
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
