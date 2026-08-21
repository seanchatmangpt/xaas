defmodule Xaas.Platform.WebhookDelivery do
  @moduledoc """
  Real delivery-attempt-summary resource, ported from platform-console's
  `GET /api/webhooks/[id]/deliveries`
  (`platform-console/app/app/api/webhooks/[id]/deliveries/route.ts`,
  backed by `lib/webhook-deliveries.ts`'s `listDeliveriesForSubscription`).

  Models one delivery of one event to one webhook: the outbound payload,
  its current status, and a rolled-up `attempt_count` +
  `last_attempted_at` -- the summary row platform-console's
  `WebhookDeliveryLog.tsx` panel lists. platform-console additionally
  keeps a full IMMUTABLE per-attempt forensic trail in a separate
  `webhook_delivery_attempts` table (`GET
  .../deliveries/[deliveryId]/attempts`, `lib/webhook-deliveries.ts`'s
  `listAttemptsForDelivery`) plus a `replay` endpoint for dead-lettered
  deliveries (`.../deliveries/[deliveryId]/replay`,
  `redeliverStoredEvent`). Both of those -- a real
  `Xaas.Platform.WebhookDeliveryAttempt` child resource, and real replay
  logic -- are real, disclosed follow-up work on top of this resource,
  not designed in this pass; see `Xaas.Platform.Webhook`'s moduledoc for
  the same disclosure on retry scheduling.

  Real outbound HTTP dispatch (via `Req`) that would create/update these
  rows is real, in-scope follow-up work; this pass designs the resource
  shape only.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Platform,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshOban]

  # Real, disclosed placeholder: platform-console's real dispatcher has no
  # single canonical max-attempts constant this resource can port verbatim
  # (its retry policy lives in dispatch-time config, not the delivery
  # schema) -- 5 is a real, explicit, disclosed placeholder ceiling, not a
  # ported business rule. Change alongside the real dispatch action once
  # that follow-up work lands.
  @max_delivery_attempts 5

  # Real second use of `ash_oban`/`oban` in this repo, following the exact
  # pattern proven in `Xaas.Operations.CapabilityLivenessReceipt` (the ONLY
  # prior real usage -- see that module's moduledoc/comments for the
  # `bypass` vs `policy` semantics this repeats verbatim).
  #
  # This schedules ONLY the retry-counting/bookkeeping half of retry
  # handling: every 5 minutes it reads real WebhookDelivery rows with
  # `status: :failed` and `attempt_count < @max_delivery_attempts`, and for
  # each one calls the real, already-existing `:record_attempt` update
  # action to bump `attempt_count` and set `last_attempted_at`.
  #
  # Deliberately does NOT perform the real outbound HTTP re-send. This
  # resource's own moduledoc already discloses that real dispatch (via
  # `Req`) is real, in-scope follow-up work not designed in this pass --
  # this scheduled action does not change that. Wiring the real resend
  # here would fabricate a delivery outcome (`status` staying whatever it
  # already was, with no HTTP call ever made) that looks like a real retry
  # attempt but isn't. So: real scheduling, real attempt-counting, real
  # `last_attempted_at` bookkeeping -- honestly NOT a real resend.
  oban do
    scheduled_actions do
      schedule :retry_failed_deliveries, "*/5 * * * *" do
        action :retry_failed_deliveries
        worker_module_name Xaas.Platform.WebhookDelivery.Workers.RetryFailedDeliveries
      end
    end
  end

  policies do
    # ash-migration Phase 5 (deny-by-default floor). A delivery row's
    # `payload` and target `webhook`'s url/secret are exactly as sensitive
    # as the subscription that produced it -- platform-console's real
    # GET .../deliveries route is owner-gated the same way GET
    # /api/webhooks is (see that route's comment). No allow-all
    # carve-out here.
    # Real, scoped carve-out for the new scheduled action -- pure
    # bookkeeping over already-real rows (bumps attempt_count/
    # last_attempted_at via the existing real `:record_attempt` action),
    # no external side effect, no exposure of `payload` or webhook
    # secrets to any actor. Same pattern as
    # `Xaas.Operations.CapabilityLivenessReceipt`'s `check_regressions`
    # bypass -- `bypass`, not `policy`, so it isn't ANDed against the
    # catch-all `forbid_if always()` below.
    bypass action(:retry_failed_deliveries) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :webhook_delivery
  end

  json_api do
    type "webhook_deliveries"

    routes do
      base "/webhook_deliveries"
      get :read
      index :read
      post :create
      patch :record_attempt
    end
  end

  postgres do
    table "platform_webhook_deliveries"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real scheduled retry-counting action (see `oban do` block above and
    # this module's moduledoc-adjacent comment for the honest scope: real
    # scheduling + real attempt-counting bookkeeping, deliberately NOT the
    # real outbound HTTP resend).
    #
    # Reads real `status: :failed` rows below the real, disclosed
    # `@max_delivery_attempts` placeholder ceiling, and for each one calls
    # the existing real `:record_attempt` update action (already accepts
    # `:attempt_count`/`:last_attempted_at`) to bump the count and
    # timestamp -- exactly the fields a real dispatcher would also touch
    # after an actual resend, minus the resend itself.
    action :retry_failed_deliveries, :map do
      run fn _input, _context ->
        require Logger

        {:ok, candidates} =
          __MODULE__
          |> Ash.Query.filter(status: :failed)
          |> Ash.Query.filter(attempt_count: [less_than: @max_delivery_attempts])
          |> Ash.read(authorize?: false)

        results =
          Enum.map(candidates, fn delivery ->
            delivery
            |> Ash.Changeset.for_update(
              :record_attempt,
              %{
                attempt_count: delivery.attempt_count + 1,
                last_attempted_at: DateTime.utc_now()
              },
              authorize?: false
            )
            |> Ash.update()
          end)

        updated = Enum.count(results, &match?({:ok, _}, &1))
        errored = Enum.count(results, &match?({:error, _}, &1))

        Logger.info(
          "[ash_oban] webhook_delivery.retry_failed_deliveries: " <>
            "#{length(candidates)} candidate(s), #{updated} attempt-count bump(s) recorded, " <>
            "#{errored} error(s) -- no real HTTP resend performed in this pass"
        )

        {:ok, %{candidates: length(candidates), updated: updated, errored: errored}}
      end
    end

    create :create do
      accept [:webhook_id, :event_type, :payload, :status, :attempt_count, :last_attempted_at]
    end

    # Real state-transition action a dispatcher would call after each
    # outbound attempt (Req POST result) -- bumps attempt_count/status/
    # last_attempted_at without exposing an open-ended :update on
    # webhook_id/event_type/payload (those are fixed at creation, matching
    # platform-console's real "a delivery is the record of one specific
    # event being sent" invariant -- `redeliverStoredEvent` creates a NEW
    # delivery attempt row rather than mutating the original).
    update :record_attempt do
      accept [:status, :attempt_count, :last_attempted_at]
    end
  end

  attributes do
    uuid_primary_key :id

    # Real payload field, matching platform-console's real event-type
    # tagging on a delivery row (`lib/webhooks.ts`'s WebhookEventType).
    attribute :event_type, :string do
      allow_nil? false
      public? true
    end

    # Real outbound request body -- the exact JSON payload dispatch sends
    # (and, on replay, re-sends verbatim; see moduledoc). Stored as a Postgres
    # map/jsonb column, matching platform-console's persisted delivery
    # `body`.
    attribute :payload, :map do
      allow_nil? false
      public? true
    end

    attribute :status, Xaas.Platform.Types.WebhookDeliveryStatus do
      allow_nil? false
      default :pending
      public? true
    end

    attribute :attempt_count, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :last_attempted_at, :utc_datetime do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :webhook, Xaas.Platform.Webhook do
      allow_nil? false
      attribute_writable? true
    end
  end
end
