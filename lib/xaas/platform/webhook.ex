defmodule Xaas.Platform.Webhook do
  @moduledoc """
  Real webhook subscription resource, ported from platform-console's
  `POST /api/webhooks` + `GET /api/webhooks` + `DELETE /api/webhooks`
  (`platform-console/app/app/api/webhooks/route.ts`, backed by
  `lib/webhooks.ts`'s `createWebhookSubscription`/`listWebhookSubscriptions`/
  `deleteWebhookSubscription`).

  platform-console's real subscription is one `eventType` (singular) per
  row; this resource models `event_types` as an array so one subscription
  can register for several event types at once -- a real, disclosed
  widening of the source shape, not a 1:1 port. `secret` is the real HMAC
  signing secret platform-console's `deliverWebhookEvent` uses to sign
  every outbound payload it POSTs to `url` -- persisted here (unlike
  `RouteSecrets`' deliberately-not-persisted-in-cleartext k8s Secret
  values) because this secret's only real purpose is to be read back and
  used for HMAC signing at dispatch time, not proxied into a separate
  secret store this codebase has no client for.

  Real outbound HTTP dispatch (signing + POSTing a delivery via `Req`,
  already a project dep) is real, in-scope follow-up work built on top of
  this resource + `Xaas.Platform.WebhookDelivery`. Real retry
  scheduling (ash_oban-driven backoff / dead-lettering, mirroring
  platform-console's `lib/webhook-poller.ts`) is NOT designed in this
  pass -- it is a real state machine (attempt counts, backoff intervals,
  a dead-letter terminal state) that deserves its own design pass rather
  than being mechanically bolted on here.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Platform,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor). A webhook's `url` is a
    # real exfiltration vector (every event payload this app ever
    # dispatches gets POSTed there) and `secret` is a real HMAC signing
    # key -- both exactly as sensitive as platform-console's real
    # owner-gated /api/webhooks routes treat them (see route.ts's comment:
    # "Owner-gated on every verb ... a webhook subscription URL is a real
    # exfiltration vector"). No allow-all carve-out here; wire real
    # per-action rules when an authz/session model exists on this side.
    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :webhook
  end

  json_api do
    type "webhooks"

    routes do
      base "/webhooks"
      get :read
      index :read
      post :create
      delete :destroy
    end
  end

  postgres do
    table "platform_webhooks"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :url, :event_types, :secret, :enabled]
    end

    update :update do
      accept [:url, :event_types, :secret, :enabled]
    end

    destroy :destroy do
      primary? true
    end
  end

  attributes do
    uuid_primary_key :id

    # Real payload field, matching platform-console's real POST body's
    # `url` (validated there as an absolute http/https URL before
    # `createWebhookSubscription` is called -- see route.ts).
    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    attribute :url, :string do
      allow_nil? false
      public? true
    end

    # Real widening of platform-console's singular `eventType` (see
    # moduledoc) -- one subscription can register for several event
    # types. No closed enum here (unlike WebhookDeliveryStatus): the real
    # `WEBHOOK_EVENT_TYPES` list in platform-console's lib/webhooks.ts is
    # itself an evolving, app-defined constant, not a fixed domain
    # vocabulary this resource should hardcode and drift from.
    attribute :event_types, {:array, :string} do
      allow_nil? false
      default []
      public? true
    end

    # Real HMAC signing secret -- see moduledoc for why it is persisted
    # here (read back at dispatch time) rather than treated like
    # RouteSecrets' deliberately-not-persisted k8s Secret values.
    # `sensitive?` keeps it out of default Ash.Resource inspect/logging.
    attribute :secret, :string do
      allow_nil? false
      sensitive? true
      public? true
    end

    attribute :enabled, :boolean do
      allow_nil? false
      default true
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :deliveries, Xaas.Platform.WebhookDelivery
  end
end
