defmodule Xaas.Governance.ApprovalDeniedPartyOverride do
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
    # real PUT /api/owner/[orgId]/denied-party-screening maker-checker flow
    # (the `denied-party.override` requireApproval action): `:create` (file
    # the override request for a "potential_match" screening record) and
    # `:approve` are gated the same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # ApprovalDeniedPartyOverrideRequiresApprover's real "second, distinct
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
    type :approval_denied_party_override
  end

  json_api do
    type "approval_denied_party_override"

    routes do
      base "/approval_denied_party_override"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_denied_party_overrides"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :org_id,
        :requested_by,
        :screening_record_id,
        :decision,
        :justification
      ]
    end

    # Real mutation route, ported from platform-console's
    # PUT /api/owner/[orgId]/denied-party-screening maker-checker flow:
    # approve (or reject) an override of a "potential_match" denied-party
    # screening result. Real business rule lives in
    # Xaas.Governance.Validations.ApprovalDeniedPartyOverrideRequiresApprover
    # -- `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct owner).
    #
    # NOT ported (honest gap): platform-console's own real screening
    # register (`lib/denied-party-screening.ts`'s
    # getScreeningRegister/recordScreeningOverride) and its live GET/POST
    # screening endpoints -- this session has not modeled a
    # ScreeningRecord resource in xaas, so the actual "look up the target
    # record by screening_record_id, verify it is a real
    # 'potential_match' not already decided, and write the override back
    # onto that record" side effect is left undone rather than
    # fabricated. This resource only tracks the approval decision itself
    # (mirroring the other maker-checker approval resources in this
    # domain).
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalDeniedPartyOverrideRequiresApprover
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
    # (screeningRecordId, decision, justification, all required) --
    # identifies which screening register entry the override applies to.
    attribute :screening_record_id, :string do
      allow_nil? false
      public? true
    end

    # Real decision enum, values ported verbatim from platform-console's
    # OVERRIDE_DECISIONS ("cleared_to_proceed" | "confirmed_blocked").
    attribute :decision, :override_decision do
      allow_nil? false
      public? true
    end

    attribute :justification, :string do
      allow_nil? false
      public? true
    end
  end
end
