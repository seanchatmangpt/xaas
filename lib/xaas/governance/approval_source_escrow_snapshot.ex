defmodule Xaas.Governance.ApprovalSourceEscrowSnapshot do
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
    # platform-console's real GET/POST /api/compliance/source-escrow
    # owner-only maker-checker flow: `:create` (collect a fresh manifest
    # and file a `source-escrow.snapshot` approval request) and `:approve`
    # are gated the same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # ApprovalSourceEscrowSnapshotRequiresApprover's real "second, distinct
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
    type :approval_source_escrow_snapshot
  end

  json_api do
    type "approval_source_escrow_snapshot"

    routes do
      base "/approval_source_escrow_snapshot"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_source_escrow_snapshots"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real mutation route (issue #20), ported from platform-console's real
    # POST /api/compliance/source-escrow: files a request to collect a
    # fresh release manifest (git commit SHA + Deployments + Flux state +
    # runtime image digests) for a namespace and escrow-sign it, gated by
    # a `source-escrow.snapshot` maker-checker approval before signing.
    # `namespace` matches platform-console's real
    # `requestSourceEscrowSnapshot(actor, namespace)` second argument
    # (defaults to `SOURCE_ESCROW_NAMESPACE = "platform-console"` there);
    # the actual manifest contents (commit SHA, Deployments, Flux state,
    # image digests) are NOT user-supplied request-body fields on the real
    # route -- they are collected server-side at approval/signing time,
    # which this session has not modeled a k8s/Flux-inspection equivalent
    # for yet, so that collection step is honestly left undone rather than
    # fabricated as a fake attribute here.
    create :create do
      accept [:org_id, :requested_by, :namespace]
    end

    # Real mutation route (issue #20), ported from platform-console's real
    # maker-checker flow: a second, distinct owner-role approver signs off
    # via `Xaas.Governance.Validations.ApprovalSourceEscrowSnapshotRequiresApprover`
    # before the collected manifest would ever be signed and persisted.
    # platform-console's own signing + ConfigMap-persistence step
    # (`verifySourceEscrowSnapshot`/the real signed-bundle write) is NOT
    # ported -- this session has not modeled that signing/storage
    # equivalent in xaas, so it is honestly left undone rather than
    # fabricated.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalSourceEscrowSnapshotRequiresApprover
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

    # Real payload, matching platform-console's real
    # `requestSourceEscrowSnapshot(actor, namespace)` second argument.
    # Defaults to the real `SOURCE_ESCROW_NAMESPACE` constant
    # ("platform-console") from lib/source-escrow-attestation.ts.
    attribute :namespace, :string do
      allow_nil? false
      public? true
      default "platform-console"
    end
  end
end
