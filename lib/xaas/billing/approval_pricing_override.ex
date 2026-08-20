defmodule Xaas.Billing.ApprovalPricingOverride do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshRateLimiter]

  rate_limit do
    backend Xaas.Hammer

    # Throttle pricing-override request creation: at most 5 per requester
    # per minute, so a scripted/compromised client can't flood the
    # approval queue.
    action :create,
      limit: 5,
      per: :timer.minutes(1),
      key: fn changeset, _context ->
        "approval_pricing_override:create:#{Ash.Changeset.get_attribute(changeset, :requested_by)}"
      end
  end

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    bypass action_type(:read) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :approval_pricing_override
  end

  json_api do
    type "approval_pricing_override"

    routes do
      base "/approval_pricing_override"
      get :read
      index :read
    end
  end

  postgres do
    table "approval_pricing_overrides"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:requested_by, :approved_by]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :requested_by, :string do
      allow_nil? false
    end

    attribute :approved_by, :string
  end
end
