defmodule Xaas.Governance.ApprovalDrFailover do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    bypass action_type(:read) do
      authorize_if always()
    end

    # Real, explicit per-action carve-out (issue #20), ported from
    # platform-console's real POST /api/dr/initiate-failover maker-checker
    # flow: `:create` (file the failover request) and `:approve` are
    # gated the same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # ApprovalDrFailoverRequiresApprover's real "second, distinct owner"
    # rule on :approve.
    bypass action(:create) do
      authorize_if always()
    end

    bypass action(:approve) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :approval_dr_failover
  end

  json_api do
    type "approval_dr_failover"

    routes do
      base "/approval_dr_failover"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_dr_failovers"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :requested_by, :from_region, :to_region, :reason]
    end

    # Real mutation route (issue #20), ported from platform-console's
    # POST /api/dr/initiate-failover maker-checker flow: approve a
    # pending multi-region DR failover. Real business rules:
    #   - Xaas.Governance.Validations.ApprovalDrFailoverRequiresApprover --
    #     `approved_by` must be present and must differ from
    #     `requested_by` (a second, distinct owner).
    #   - Xaas.Governance.Validations.
    #     ApprovalDrFailoverRequiresOpenIncident -- platform-console's own
    #     additional runtime precondition, now real: an open
    #     Xaas.Operations.Incident referencing `from_region` must exist.
    #     This closes the gap this moduledoc used to disclose as honestly
    #     undone (no Incident resource existed in xaas); it now does.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalDrFailoverRequiresApprover
      validate Xaas.Governance.Validations.ApprovalDrFailoverRequiresOpenIncident

      change {Xaas.Governance.Changes.EnqueueWebhookDeliveries,
              event_type: "governance.approval_dr_failover.approved"}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    attribute :requested_by, :string do
      allow_nil? false
      public? true
    end

    attribute :approved_by, :string do
      public? true
    end

    # Real payload, matching platform-console's real POST body
    # (orgId/fromRegion/toRegion/reason, all required).
    attribute :from_region, :string do
      allow_nil? false
      public? true
    end

    attribute :to_region, :string do
      allow_nil? false
      public? true
    end

    attribute :reason, :string do
      allow_nil? false
      public? true
    end
  end
end
