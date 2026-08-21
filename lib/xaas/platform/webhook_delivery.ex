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
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor). A delivery row's
    # `payload` and target `webhook`'s url/secret are exactly as sensitive
    # as the subscription that produced it -- platform-console's real
    # GET .../deliveries route is owner-gated the same way GET
    # /api/webhooks is (see that route's comment). No allow-all
    # carve-out here.
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
