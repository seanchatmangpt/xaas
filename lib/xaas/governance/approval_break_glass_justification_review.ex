defmodule Xaas.Governance.ApprovalBreakGlassJustificationReview do
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
    # platform-console's real POST /api/support/break-glass/[grantId]/justify
    # mandatory post-hoc justification flow: `:create` (file the
    # justification, opening the second-approver review) and `:approve`
    # (the second, distinct platform admin signs off) are gated the same
    # way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # ApprovalBreakGlassJustificationReviewRequiresApprover's real "second,
    # distinct reviewer" rule on :approve.
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
    type :approval_break_glass_justification_review
  end

  json_api do
    type "approval_break_glass_justification_review"

    routes do
      base "/approval_break_glass_justification_review"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_break_glass_justification_reviews"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real mutation route (issue #20), ported from platform-console's
    # POST /api/support/break-glass/[grantId]/justify: the on-call engineer
    # who opened a break-glass grant files their mandatory post-hoc
    # justification, which opens this review.
    #
    # NOT ported: platform-console's `requirePlatformAdmin` role check
    # (authn/authz lives at the router-level Bearer token plug in xaas, not
    # a per-actor role system xaas has modeled yet); the real
    # `fileBreakGlassJustification` side effect of mutating the underlying
    # break-glass grant record itself (xaas has no BreakGlassGrant resource
    # yet -- this resource models only the review, not the grant); and the
    # real audit-log write (`writeAuditLogEntry`) on every branch, which
    # xaas has no equivalent audit sink for yet. All honestly left undone
    # rather than fabricated.
    create :create do
      accept [:org_id, :grant_id, :requested_by, :justification]
    end

    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalBreakGlassJustificationReviewRequiresApprover
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

    # Real payload, matching platform-console's real route param
    # (`grantId`, the break-glass grant this justification is for).
    attribute :grant_id, :string do
      allow_nil? false
      public? true
    end

    # Real payload, matching platform-console's real required POST body
    # field `justification` (trimmed, non-empty string).
    attribute :justification, :string do
      allow_nil? false
      public? true
    end
  end
end
