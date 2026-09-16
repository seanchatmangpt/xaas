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
    extensions: [AshOban]

  postgres do
    table("ultracode_runs")
    repo(Xaas.Repo)
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
    end
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    # XAAS-2601: `:tick` (cron-fired), `:advance_cycle` and
    # `:transition_state` (Ultracode Reactor pipeline) are internal-only
    # mutations, admitted by the REAL system authority predicate instead
    # of the previous action-wide `authorize_if(always())` bypasses --
    # which any caller through the normal authorization path satisfied.
    # `:tick` accepts no external arguments and exposes no Run/Epoch
    # field to a caller; `:advance_cycle`/`:transition_state` accept no
    # actor, capability, or execution context a bypass could have checked
    # -- the system-actor check IS that missing internal predicate.
    bypass action([:tick, :advance_cycle, :transition_state]) do
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    policy always() do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:goal, :deadline_at, :max_cycles, :epoch_timeout_seconds])
    end

    update :advance_cycle do
      accept([])
      change(increment(:cycle))
    end

    update :mark_expected_epoch do
      accept([:last_expected_epoch_at])
    end

    update :mark_completed_epoch do
      accept([:last_completed_epoch_at])
    end

    update :transition_state do
      accept([:state, :standing])
      require_atomic?(false)

      validate({Xaas.Ultracode.Validations.RunTransitionAllowed, []})
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

    attribute :goal, :string do
      allow_nil?(false)
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
    # different tolerance for a missed cycle.
    attribute :epoch_timeout_seconds, :integer do
      allow_nil?(false)
      default(300)
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
    has_many :epochs, Xaas.Ultracode.Epoch

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
    end
  end
end
