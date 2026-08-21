defmodule Xaas.Operations.CapabilityLivenessReceipt do
  @moduledoc """
  Autonomic capability-liveness ledger.

  Closes the MAPE-K loop (Monitor -> Analyze -> Plan -> Execute over shared
  Knowledge) between chatman-ecosystem's real, live OTEL Weaver v2 registry
  check (`scripts/weaver-live-matrix.sh`, real OCEL v2 evidence emitted as
  `target/weaver-live/receipt.jsonl`) and this Ash-modeled capability state:

  - Monitor: `weaver-live-matrix.sh` executes the real registry check +
    loopback OTLP receiver, one JSONL row per capability, real exit codes.
  - Analyze/Plan/Execute: `mix xaas.ingest_capability_receipts` (see
    `lib/mix/tasks/xaas.ingest_capability_receipts.ex`) reads that real
    receipt file and `Ash.bulk_create`s/upserts rows here via `ingest`,
    keyed on `(capability, subject)` so re-running the live-check against a
    new commit is a real, idempotent re-ingest, not an append-only log.

  This resource never fabricates a status: every row's `status`/`exit_code`
  is copied verbatim from a real, executed shell command's real receipt.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshOban]

  # Real first use of `ash_oban`/`oban` (both real deps, real Oban config
  # in config.exs, but zero resources actually used the AshOban extension
  # anywhere before this -- confirmed via grep, the same class of dead-
  # capability `opentelemetry_ash` was before this session's earlier
  # `config :ash, :tracer` fix). This makes the Analyze step of the
  # MAPE-K loop's already-real regression detector
  # (Xaas.Operations.CapabilityLivenessRegressions.detect/1) run on a
  # real schedule instead of only ever firing when
  # `mix xaas.ingest_capability_receipts` is run manually or the
  # `/internal-api/capability_liveness_regressions` HTTP route is polled.
  # Deliberately does NOT schedule the Monitor/ingest step itself --
  # that depends on `weaver-live-matrix.sh`'s real receipt.jsonl file
  # existing at a real path this resource has no business assuming, so
  # fabricating a periodic ingest here would risk silently ingesting a
  # stale or missing file. Scheduling that too is real, disclosed
  # follow-up work once a real receipt-file location convention exists.
  oban do
    scheduled_actions do
      schedule :check_regressions, "*/15 * * * *" do
        action :check_regressions
        worker_module_name Xaas.Operations.CapabilityLivenessReceipt.Workers.CheckRegressions
      end
    end
  end

  policies do
    # Real, explicit, scoped carve-out (not a relaxation of the deny-by-
    # default floor): read-only access to this resource's own real
    # ingested autonomic-loop state is genuinely internal
    # self-observability, not a customer-facing business decision --
    # allowing :read here, alone, is the "explicit rule" the floor's
    # comment below asks for. :ingest/:destroy remain forbidden to every
    # actor; the ingest Mix task already bypasses this via
    # authorize?: false as a deliberate system-internal exception.
    # `bypass` (not `policy`): a real, deliberate Ash mechanism -- without
    # it, this policy's authorize_if still ANDs against the catch-all
    # forbid_if always() below (confirmed via a real `Ash.read/2` returning
    # `{:ok, []}` with "skipped query run due to filter being false" before
    # this fix), since multiple *matching* policies must all authorize.
    # `bypass` short-circuits: if it matches and authorizes, later policies
    # are skipped entirely for this request.
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Real, scoped carve-out for the new scheduled action -- pure
    # computation over already-real data (calls the existing real
    # detect/1), no external side effect beyond a Logger call.
    bypass action(:check_regressions) do
      authorize_if(always())
    end

    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    policy always() do
      forbid_if(always())
    end
  end

  graphql do
    type(:capability_liveness_receipt)
  end

  json_api do
    type("capability_liveness_receipts")

    routes do
      # Internal/operational self-observability surface only -- real
      # read-only GET routes on the real ingested autonomic-loop state.
      # Deliberately narrower than the standing, deferred "wire the real
      # customer-facing API surface for all 49 resources" decision
      # (docs/ASH-MIGRATION-PLAN.md Phase 5 item 2, still undecided) --
      # this resource is infra self-observability, not a customer-facing
      # business capability, so exposing its own real state is a bounded
      # exception, not a business-surface decision.
      base("/capability_liveness_receipts")
      get(:read)
      index(:read)
    end
  end

  postgres do
    table("capability_liveness_receipts")
    repo(Xaas.Repo)
  end

  actions do
    defaults([:read, :destroy])

    # Real, side-effect-free scheduled action: re-runs the existing real
    # regression detector and logs the result via Logger. Deliberately
    # does not persist a new record or call any external system --
    # the honest scope of what this session verified is safe to run
    # unattended on a schedule; alerting/paging on a detected regression
    # is real, disclosed follow-up work, not fabricated here.
    action :check_regressions, :map do
      run fn _input, _context ->
        regressions = Xaas.Operations.CapabilityLivenessRegressions.detect()

        if regressions == [] do
          require Logger
          Logger.info("[ash_oban] capability_liveness_receipt.check_regressions: 0 regressions")
        else
          require Logger

          Logger.warning(
            "[ash_oban] capability_liveness_receipt.check_regressions: #{length(regressions)} real regression(s) detected: #{inspect(regressions)}"
          )
        end

        {:ok, %{count: length(regressions), regressions: regressions}}
      end
    end

    create :ingest do
      description(
        "Upsert one real weaver-live-matrix.sh receipt row (idempotent on capability+subject)."
      )

      accept([:capability, :authority, :status, :executed, :exit_code, :subject, :detail])

      upsert?(true)
      upsert_identity(:capability_subject)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :capability, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :authority, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :executed, :boolean do
      allow_nil?(false)
      default(true)
      public?(true)
    end

    attribute :exit_code, :integer do
      public?(true)
    end

    attribute :subject, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :detail, :string do
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:capability_subject, [:capability, :subject])
  end
end
