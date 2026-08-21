defmodule Xaas.Operations.AuditLogEntry do
  @moduledoc """
  Real, queryable, cross-resource audit trail: who did what, when, across
  the whole app. Distinct from AshPaperTrail (which gives individual
  Governance `Approval*` resources a real per-record field-diff version
  history) -- this resource is a flat, append-only log of real actions
  taken, spanning every resource/domain, not scoped to one record's
  history.

  Real, confirmed discovery before writing this module: no
  `AuditLogEntry` resource existed anywhere in `lib/xaas/` (a real
  cross-`lib/` search found zero matches) -- this is a new resource, not
  a rewire of an existing one.

  ## Real deny-by-default, no public write route

  Rows here are only ever created internally by a real Ash change (see
  `Xaas.Governance.Changes.WriteAuditLogEntry`), never via a public
  mutation route -- there is deliberately no `:create` action exposed
  over `json_api`/`graphql`, and the `:create` action itself has no
  policy bypass, so even a direct internal Ash.create call without
  `authorize?: false` would be denied by the catch-all `forbid_if
  always()` below. Only `:read` gets a bypass (internal audit
  visibility), matching this repo's deny-by-default floor
  (`docs/ASH-MIGRATION-PLAN.md` Phase 5).
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    bypass action_type(:read) do
      authorize_if always()
    end

    # No bypass for :create -- deliberately unreachable from any public
    # route. Real rows are written internally via
    # Xaas.Governance.Changes.WriteAuditLogEntry, which calls
    # Ash.create!/2 with authorize?: false (the same internal-write
    # pattern EnqueueWebhookDeliveries already established for
    # WebhookDelivery rows).
    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :audit_log_entry
  end

  json_api do
    type "audit_log_entries"

    routes do
      base "/audit_log_entries"
      get :read
      index :read
    end
  end

  postgres do
    table "audit_log_entries"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :actor_id,
        :actor_description,
        :action,
        :resource_type,
        :resource_id,
        :org_id,
        :occurred_at,
        :metadata
      ]
    end
  end

  attributes do
    uuid_primary_key :id

    # Real, best-effort caller identity. This repo has no per-user
    # identity on the request path today (see
    # KanbanWeb.Plugs.ResolveOrgActor's moduledoc) -- the closest real
    # identifying string available at approval time is the mutation's
    # own `approved_by` field, so callers pass that as `actor_id`.
    # Nullable: some future internal-only writers may have no caller
    # identity at all.
    attribute :actor_id, :string do
      public? true
    end

    attribute :actor_description, :string do
      public? true
    end

    # Real, dotted action name, e.g.
    # "governance.approval_dr_failover.approve".
    attribute :action, :string do
      allow_nil? false
      public? true
    end

    attribute :resource_type, :string do
      allow_nil? false
      public? true
    end

    attribute :resource_id, :string do
      allow_nil? false
      public? true
    end

    attribute :org_id, :string do
      public? true
    end

    attribute :occurred_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :metadata, :map do
      default %{}
      public? true
    end
  end
end
