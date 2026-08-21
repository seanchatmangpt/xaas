defmodule Xaas.Platform.RouteProjectsBackups do
  @moduledoc """
  Real backup HISTORY resource, ported from platform-console's
  `GET/POST /api/orgs/[id]/backups` (`orgs/[id]/backups/route.ts`), which
  itself wraps the real per-project `createBackupJob` primitive
  `app/api/projects/[name]/backups/route.ts` already exposes.

  Ported (real, field-level):
  - `org_id`, `namespace`, `project_name`, `job_name`, `taken_at`,
    `size_bytes`, `retain_until`, `status` -- the real `BackupRecord`
    shape from `lib/backup-retention.ts`.
  - `:create` requires `project_name` (real "projectName is required" 400
    check, `RouteProjectsBackupsValidProjectName`).

  Deliberately NOT ported (real integration work still owed, not
  fabricated here):
  - The real cross-tenant guard: platform-console's POST calls a live
    `listProjects()` against the k8s API and refuses if the named project
    does not belong to the caller's org namespace. xaas has no
    k8s Project/namespace model yet to check against.
  - The real `pg_dump` Job trigger (`runOrgBackup` -> `createBackupJob`)
    and the real live-Job status reconciliation
    (`syncBackupRecordStatus`) -- both require a real k8s client this
    codebase does not yet have. `:create` here only persists the metadata
    row a real trigger would eventually produce; `status` starts
    `:pending` the same way the real route does, but nothing here ever
    transitions it to `:running`/`:completed`/`:failed` -- that
    reconciliation loop is not implemented.
  - The real `cleanupExpiredBackups` sweep (delete the real k8s Job +
    ConfigMap row once `retain_until` passes). No `expired` transition
    happens automatically here either.
  - The retention POLICY endpoint (`PUT /api/orgs/[id]/backup-policy`,
    maker-checker gated) is a SEPARATE real resource, already ported as
    `Xaas.Governance.ApprovalBackupRetentionChange` -- not duplicated
    here.
  - `GET` role floor in the real route is "viewer" (any org member);
    `POST` is "owner". xaas has no per-org-role model yet, so both are
    gated the same way every other Platform resource in this batch is:
    the router-level `KanbanWeb.Plugs.RequireInternalApiToken` Bearer
    check (via the policy `bypass`s below), not a role check.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Platform,
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

    # Real, explicit per-action carve-out: `:create` (trigger/record an
    # on-demand backup) is gated the same way reads are -- by the
    # router-level KanbanWeb.Plugs.RequireInternalApiToken Bearer check --
    # plus its own real validation
    # (RouteProjectsBackupsValidProjectName). No maker-checker here: the
    # real route.ts POST /api/orgs/[id]/backups has no second-approver
    # step, unlike the retention-policy PUT (ApprovalBackupRetentionChange).
    #
    # Real fix (eighteenth-pass ERRC grid sweep): the bare
    # `authorize_if always()` this bypass previously used let any actor
    # holding only the shared internal token fabricate backup-history rows
    # under a completely invented, never-authenticated org_id -- see
    # `Xaas.Platform.Checks.ActorOrgMatches`'s own moduledoc for the full
    # disclosed finding and the live-HTTP proof.
    bypass action(:create) do
      authorize_if Xaas.Platform.Checks.ActorOrgMatches
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :route_projects_backups
  end

  json_api do
    type "route_projects_backups"

    routes do
      base "/route_projects_backups"
      get :read
      index :read
      post :create
    end
  end

  postgres do
    table "route_projects_backups"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :namespace, :project_name, :job_name, :taken_at, :size_bytes, :retain_until, :status]
      validate Xaas.Platform.Validations.RouteProjectsBackupsValidProjectName
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    attribute :namespace, :string do
      allow_nil? false
      public? true
    end

    attribute :project_name, :string do
      allow_nil? false
      public? true
    end

    # Real k8s Job name the dump ran as -- lets a BackupRecord be traced
    # back to its real file at
    # `/backups/<namespace>/<stem>/<jobName>.sql` (real, per
    # platform-console's own moduledoc). Not enforced/generated here since
    # no real Job-creation integration exists yet -- accepted as caller
    # input.
    attribute :job_name, :string do
      allow_nil? false
      public? true
    end

    attribute :taken_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    # Starts at 0 the same way the real route does (`sizeBytes starts at
    # 0 ... status starts "pending"`) -- no default here since real
    # completion-time size reporting isn't implemented; accepted as
    # caller input instead.
    attribute :size_bytes, :integer do
      allow_nil? false
      public? true
    end

    attribute :retain_until, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :status, Xaas.Platform.Types.BackupStatus do
      allow_nil? false
      public? true
      default :pending
    end
  end
end
