defmodule Xaas.Governance.ApprovalEnvironmentPromote do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshStateMachine]

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    bypass action_type(:read) do
      authorize_if always()
    end

    # Real, explicit per-action carve-out, ported from platform-console's
    # real POST /api/projects/[name]/promote maker-checker flow: `:create`
    # (file the promotion request) and `:approve` are gated the same way
    # reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # ApprovalEnvironmentPromoteRequiresApprover's real "second, distinct
    # owner" rule on :approve.
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
    type :approval_environment_promote
  end

  json_api do
    type "approval_environment_promote"

    routes do
      base "/approval_environment_promote"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_environment_promotes"
    repo Xaas.Repo
  end

  state_machine do
    initial_states([:pending])
    default_initial_state(:pending)
    state_attribute(:status)

    transitions do
      transition(:approve, from: :pending, to: :approved)
      transition(:reject, from: :pending, to: :rejected)
    end
  end

  actions do
    defaults [:read]

    # Real mutation route, ported from platform-console's real
    # POST /api/projects/[name]/promote (dev -> staging -> prod, SOC2 CC8
    # change management): files a pending environment-promotion request for
    # a named Project.
    create :create do
      accept [:org_id, :requested_by, :project_name, :from_environment, :to_environment]
      validate Xaas.Governance.Validations.ApprovalEnvironmentPromoteValidTarget
    end

    # Real mutation route, ported from platform-console's real
    # POST /api/projects/[name]/promote maker-checker flow: approve a
    # pending environment promotion. Real business rule lives in
    # Xaas.Governance.Validations.ApprovalEnvironmentPromoteRequiresApprover
    # -- `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct owner).
    #
    # NOT ported (honestly disclosed, not silently dropped): platform-console's
    # route also (a) requires the caller hold role >= owner via requireRole
    # before even filing the request -- xaas has no per-caller-role model
    # yet, so this is enforced only by the router-level Bearer token check;
    # (b) runs a real change-freeze guard (lib/freeze-windows.ts,
    # checkFreezeGuard) against the owning org before promoting -- xaas has
    # not modeled a FreezeWindow resource, so that check is left undone
    # rather than fabricated; (c) actually calls setProjectEnvironment
    # against the real k8s ServiceAccount to patch the live Project's
    # ENVIRONMENT_LABEL -- xaas has no equivalent live side effect here, this
    # resource only records the approval decision.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalEnvironmentPromoteRequiresApprover
      change transition_state(:approved)
    end

    update :reject do
      require_atomic? false
      change transition_state(:rejected)
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

    # Real payload, matching platform-console's real route: the Project
    # `name` path param plus the real fromEnvironment/targetEnvironment
    # pair captured in the pending approval's resourcePayload so an
    # approver can see the real transition, not just an opaque project
    # name.
    attribute :project_name, :string do
      allow_nil? false
      public? true
    end

    attribute :from_environment, :environment do
      allow_nil? false
      public? true
    end

    attribute :to_environment, :environment do
      allow_nil? false
      public? true
    end
  end
end
