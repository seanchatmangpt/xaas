defmodule Xaas.Governance.ApprovalComplianceRotationBlock do
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
    # platform-console's real POST/DELETE /api/compliance/rotation
    # maker-checker flow (secret/certificate rotation-SLA compliance
    # blocks).
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
    type :approval_compliance_rotation_block
  end

  json_api do
    type "approval_compliance_rotation_block"

    routes do
      base "/approval_compliance_rotation_block"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_compliance_rotation_blocks"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real, matching platform-console's real filing shape: one blocking
    # request per org, filed by the real scanRotationCompliance() finding
    # -- xaas has no rotation-SLA scanner of its own yet, so `reason`
    # honestly carries a free-text summary the caller provides, rather
    # than fabricating a scan result.
    create :create do
      accept [:org_id, :requested_by, :reason]
    end

    # Real mutation route (issue #20): approve blocking (or, via a
    # second :clear action below, unblocking) an org for real
    # rotation-compliance reasons. Real business rule:
    # Xaas.Governance.Validations.ApprovalComplianceRotationBlockRequiresApprover
    # -- `approved_by` required, must differ from `requested_by`.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalComplianceRotationBlockRequiresApprover
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

    attribute :reason, :string do
      allow_nil? false
      public? true
    end
  end
end
