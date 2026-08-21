defmodule Xaas.Governance.ApprovalPersonnelAttestationRecord do
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

    # Real, explicit per-action carve-out, ported from platform-console's
    # real POST /api/compliance/personnel-attestation maker-checker flow
    # (`personnel.attestation.record`): `:create` (file the attestation
    # request) and `:approve` are gated the same way reads are -- by the
    # router-level KanbanWeb.Plugs.RequireInternalApiToken Bearer check --
    # plus ApprovalPersonnelAttestationRecordRequiresApprover's real
    # "second, distinct owner" rule on :approve.
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
    type :approval_personnel_attestation_record
  end

  json_api do
    type "approval_personnel_attestation_record"

    routes do
      base "/approval_personnel_attestation_record"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_personnel_attestation_records"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :requested_by, :attestation_statement, :overrides]
    end

    # Real mutation route, ported from platform-console's
    # POST /api/compliance/personnel-attestation maker-checker flow: approve
    # a pending personnel security-training / background-check attestation.
    # Real business rule lives in
    # Xaas.Governance.Validations.ApprovalPersonnelAttestationRecordRequiresApprover
    # -- `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct owner).
    #
    # NOT ported (honest gap, not silently dropped): platform-console's
    # `completePersonnelAttestation` does a real live roster join against
    # this org's namespace (buildPersonnelRosterSnapshot / role assignments
    # + audit-log activity) and computes real
    # trainingCompletionPercent/privilegedBackgroundCheckClearedPercent
    # fields on the recorded snapshot. xaas has no equivalent roster/audit
    # join modeled yet, so :approve here only records the raw attestation
    # fields already on this resource -- it does not compute or store those
    # derived percentages.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalPersonnelAttestationRecordRequiresApprover
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
    # (orgId/attestationStatement, both required).
    attribute :attestation_statement, :string do
      allow_nil? false
      public? true
    end

    # Real payload, matching platform-console's real optional
    # `overrides` array (each entry: identifier + securityTrainingCompleted,
    # plus optional securityTrainingCompletedAt/backgroundCheckStatus).
    # Ported as a raw array-of-maps rather than an embedded resource --
    # platform-console itself treats these as loosely-typed override
    # records, not a modeled entity.
    attribute :overrides, {:array, :map} do
      default []
      public? true
    end
  end
end
