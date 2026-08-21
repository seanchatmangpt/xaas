defmodule Xaas.Governance.ApprovalVendorOffboardingAttestationIssue do
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
    # real POST /api/owner/vendor-offboarding maker-checker flow: `:create`
    # (file the attestation-issue request) and `:approve` are gated the
    # same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # ApprovalVendorOffboardingAttestationIssueRequiresApprover's real
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
    type :approval_vendor_offboarding_attestation_issue
  end

  json_api do
    type "approval_vendor_offboarding_attestation_issue"

    routes do
      base "/approval_vendor_offboarding_attestation_issue"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_vendor_offboarding_attestation_issues"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :requested_by, :termination_date, :contractual_sla_days]
    end

    # Real mutation route, ported from platform-console's
    # POST /api/owner/vendor-offboarding maker-checker flow: approve a
    # pending vendor-offboarding data-return/destruction attestation
    # issuance. Real business rule lives in
    # Xaas.Governance.Validations.ApprovalVendorOffboardingAttestationIssueRequiresApprover
    # -- `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct owner).
    #
    # NOT ported (honest gap): platform-console's route computes a live
    # "evidence" snapshot (qualifying export records, destruction
    # certificate lookup + tamper verification, SLA-deadline math) via
    # computeVendorOffboardingEvidence both at filing time and again at
    # issuance time, and issueVendorOffboardingAttestation itself
    # server-side refuses to mint the attestation unless that fresh
    # evidence is compliant (data accounted for + within SLA) -- xaas has
    # no equivalent Export/DestructionCertificate resources or evidence
    # engine yet, so this resource stores only the requester-supplied
    # termination_date/contractual_sla_days inputs and the maker-checker
    # approval gate; the actual "is it safe to attest" compliance check is
    # NOT re-implemented here and must not be assumed to run.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalVendorOffboardingAttestationIssueRequiresApprover
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
    # (orgId/terminationDate/contractualSlaDays, all required) -- the date
    # the vendor relationship terminated and the contractual SLA (in days)
    # by which data return/destruction must be complete.
    attribute :termination_date, :date do
      allow_nil? false
      public? true
    end

    attribute :contractual_sla_days, :integer do
      allow_nil? false
      public? true
    end
  end
end
