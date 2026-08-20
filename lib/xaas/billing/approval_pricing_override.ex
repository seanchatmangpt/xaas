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

    # Real, explicit per-action carve-out (issue #20): the `:approve` action
    # is gated the same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus its own
    # real validation (ApprovalPricingOverrideRequiresApprover) rejecting a
    # missing or self-approving `approved_by`. This is a deliberate decision
    # for this one action, not a blanket allow of every mutation.
    bypass action(:approve) do
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
      patch :approve
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

    # Real mutation route (issue #20): approve a pending pricing-override
    # request. Business rule lives in
    # Xaas.Billing.Validations.ApprovalPricingOverrideRequiresApprover --
    # `approved_by` must be present and must differ from `requested_by`.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      change Xaas.Billing.Changes.ApprovalPricingOverrideApprove
      validate Xaas.Billing.Validations.ApprovalPricingOverrideRequiresApprover
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :requested_by, :string do
      allow_nil? false
      public? true
    end

    attribute :approved_by, :string do
      public? true
    end
  end
end
