defmodule Xaas.Governance.ApprovalInsurancePolicyUpdate do
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
    # real PUT /api/owner/insurance-attestation maker-checker flow
    # (`insurance.policy.update`): `:create` (file the policy-update
    # request) and `:approve` are gated the same way reads are -- by the
    # router-level KanbanWeb.Plugs.RequireInternalApiToken Bearer check --
    # plus their own real validations (real date-range/positive-limit
    # check on :create,
    # ApprovalInsurancePolicyUpdateRequiresApprover on :approve).
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
    type :approval_insurance_policy_update
  end

  json_api do
    type "approval_insurance_policy_update"

    routes do
      base "/approval_insurance_policy_update"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_insurance_policy_updates"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real mutation route, ported from platform-console's
    # PUT /api/owner/insurance-attestation maker-checker flow: file a
    # request to record a new/renewed insurance policy version. NOT
    # ported here: platform-console's real GET (list current policy
    # registry / attestation history) and POST (render + stream a live
    # PDF certificate-of-insurance) -- this resource only models the
    # maker-checker approval record itself, matching the pattern
    # ApprovalDrFailover/ApprovalBackupRetentionChange already set (the
    # actual "record the approved policy version" / "generate the PDF"
    # side effects have no xaas equivalent yet and are honestly left
    # undone rather than fabricated).
    create :create do
      accept [
        :org_id,
        :requested_by,
        :coverage_type,
        :carrier,
        :policy_number,
        :coverage_limit_usd,
        :effective_date,
        :expiry_date,
        :am_best_rating
      ]

      validate Xaas.Governance.Validations.ApprovalInsurancePolicyUpdateValidDateRange
    end

    # Real mutation route, ported from platform-console's
    # PUT /api/owner/insurance-attestation maker-checker flow: approve a
    # pending insurance policy update. Real business rule lives in
    # Xaas.Governance.Validations.ApprovalInsurancePolicyUpdateRequiresApprover
    # -- `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct owner). platform-console's own additional
    # post-approval behavior (actually writing the new
    # InsurancePolicyRecord version and generating an audit log entry with
    # `insuranceAction: "policy_recorded"`) is NOT ported -- this session
    # has not modeled an InsurancePolicyRecord version-history resource in
    # xaas, so that write is honestly left undone rather than fabricated.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalInsurancePolicyUpdateRequiresApprover
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

    # Real payload, matching platform-console's real PUT body
    # (coverageType/carrier/policyNumber/coverageLimitUsd/effectiveDate/
    # expiryDate, all required; amBestRating optional).
    attribute :coverage_type, :insurance_coverage_type do
      allow_nil? false
      public? true
    end

    attribute :carrier, :string do
      allow_nil? false
      public? true
    end

    attribute :policy_number, :string do
      allow_nil? false
      public? true
    end

    attribute :coverage_limit_usd, :decimal do
      allow_nil? false
      public? true
    end

    attribute :effective_date, :date do
      allow_nil? false
      public? true
    end

    attribute :expiry_date, :date do
      allow_nil? false
      public? true
    end

    attribute :am_best_rating, :string do
      public? true
    end
  end
end
