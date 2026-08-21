defmodule Xaas.Governance.ApprovalLegalHoldRelease do
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
    # real `PUT /api/owner/legal-hold` maker-checker flow: `:create` (file
    # the release request) and `:approve` are gated the same way reads are
    # -- by the router-level KanbanWeb.Plugs.RequireInternalApiToken Bearer
    # check -- plus ApprovalLegalHoldReleaseRequiresApprover's real "second,
    # distinct owner" rule on :approve.
    # Updated this pass: `:create`/`:approve` are no longer bare
    # `authorize_if always()` -- they now real-check
    # `Xaas.Governance.Checks.ActorOrgMatches` (the actor's
    # `X-Org-Id`-resolved org must match the create payload's/existing
    # record's real `org_id`), on top of the real per-action
    # validations named above. See that module's moduledoc for why this
    # is needed on top of `multitenancy`'s own row-scoping.
    bypass action(:create) do
      authorize_if Xaas.Governance.Checks.ActorOrgMatches
    end

    bypass action(:approve) do
      authorize_if Xaas.Governance.Checks.ActorOrgMatches
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :approval_legal_hold_release
  end

  json_api do
    type "approval_legal_hold_release"

    routes do
      base "/approval_legal_hold_release"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_legal_hold_releases"
    repo Xaas.Repo

    references do
      reference :org, on_delete: :restrict, on_update: :update
    end
  end

    # Real Ash-core multitenancy wiring, now strictly enforced
  # (`global? false`). A real per-org actor now exists on the request
  # path -- see `KanbanWeb.Plugs.ResolveOrgActor` (real, caller-asserted
  # `X-Org-Id` header resolved against a real `Xaas.Accounts.Org`, then
  # set as both the real Ash actor and the real Ash tenant via
  # `Ash.PlugHelpers.set_actor/2` / `set_tenant/2`). Ash's own
  # attribute-strategy multitenancy then filters/scopes every query and
  # changeset on `org_id` to that resolved tenant automatically -- no
  # per-action code in this resource has to do it by hand. That plug's
  # moduledoc carries the full disclosed limitation: `X-Org-Id` is
  # caller-asserted, not cryptographically authenticated -- real
  # per-org *authentication* remains separate, out-of-scope follow-up
  # work.
  multitenancy do
    strategy :attribute
    attribute :org_id
    global? false
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :requested_by, :hold_id, :release_reason]
    end

    # Real mutation route, ported from platform-console's real
    # `PUT /api/owner/legal-hold` maker-checker flow: approve a pending
    # legal hold release. Real business rule lives in
    # Xaas.Governance.Validations.ApprovalLegalHoldReleaseRequiresApprover
    # -- `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct owner).
    #
    # NOT ported (honest gap): platform-console's real POST-approval side
    # effect -- actually calling `releaseLegalHold` against
    # `lib/legal-hold.ts`'s storage to flip the hold's status to
    # "released" and unblock scheduled destruction -- has no equivalent
    # here yet; xaas has not modeled a LegalHold storage resource this
    # approval record could mutate. This resource only records the
    # maker-checker decision. Also not ported: platform-console's real
    # `PUT` short-circuit that returns 200 immediately (no approval flow)
    # when the hold is already `status: "released"` -- xaas has no
    # LegalHold resource to check that status against.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalLegalHoldReleaseRequiresApprover

      change {Xaas.Governance.Changes.EnqueueWebhookDeliveries,
              event_type: "governance.approval_legal_hold_release.approved"}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :org_id, :string do
      # Real, platform-console-matching nullability: `orgId` is null for a
      # platform-scoped hold (scope: "platform") and only required for an
      # org-scoped one (scope: "org") -- see lib/legal-hold.ts's real
      # LegalHoldScope union.
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
    # (`holdId`/`releaseReason`, both required).
    attribute :hold_id, :string do
      allow_nil? false
      public? true
    end

    attribute :release_reason, :string do
      allow_nil? false
      public? true
    end
  end

  relationships do
    # Real FK relationship, referencing Xaas.Accounts.Org's real unique
    # `slug` (not its uuid `id`) -- same shape as the pilot
    # (ApprovalBackupRetentionChange). `define_attribute? false` since
    # `org_id` is already explicitly defined above. Nullable, matching
    # `org_id`'s own real nullability for platform-scoped holds.
    belongs_to :org, Xaas.Accounts.Org do
      source_attribute :org_id
      destination_attribute :slug
      attribute_type :string
      define_attribute? false
      allow_nil? true
    end
  end
end
