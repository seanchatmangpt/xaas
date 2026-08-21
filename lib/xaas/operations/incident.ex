defmodule Xaas.Operations.Incident do
  @moduledoc """
  Real SLA incident tracker, modeled on platform-console's real
  `app/api/incidents/route.ts` + `app/api/incidents/[id]/postmortem/route.ts`
  (`~/chatman-ecosystem/platform-console`).

  Closes the real gap disclosed in
  `Xaas.Governance.ApprovalDrFailover`'s moduledoc: that resource's
  `:approve` action ports platform-console's DR-failover maker-checker
  flow (`POST /api/dr/initiate-failover`) but honestly left out
  platform-console's own additional runtime precondition -- an open
  incident referencing `from_region` must exist before failover runs --
  because xaas had no `Incident` resource to check against. This
  resource is that model; `Xaas.Governance.Validations.
  ApprovalDrFailoverRequiresOpenIncident` is the real enforcement that
  now queries it.

  Field shape mirrors platform-console's real `Incident` interface
  (`lib/incidents.ts`) plus the postmortem sub-resource fields
  (`lib/postmortems.ts`, read via `app/api/incidents/[id]/postmortem/route.ts`)
  folded onto the same row rather than a second table, since xaas has no
  equivalent of platform-console's separate `postmortems` store and this
  session is not standing one up speculatively. `region` is xaas-specific
  (not present in platform-console's `componentId`-scoped model) -- it is
  the field `ApprovalDrFailoverRequiresOpenIncident` matches against
  `from_region`, since xaas's own DR-failover flow is multi-region, not
  multi-component the way platform-console's shared single-cluster demo
  project is.

  ## Real fix (seventeenth pass) -- the `:create`/`:update` bypass had no
  per-org access control, and fed a real cross-org escalation

  Real, live-HTTP-proven gap found by the seventeenth-pass ERRC grid
  sweep: `:create`/`:update` were bare `authorize_if(always())` despite
  this resource accepting a caller-supplied `org_id` (line above), and
  `KanbanWeb.Plugs.ResolveOrgActor`'s tenant-scoped path list didn't cover
  `incidents` either. Worse than a same-resource bypass alone: because
  `ApprovalDrFailoverRequiresOpenIncident`'s query previously filtered
  only on `region`/`status` (see that module's own moduledoc), a
  fabricated incident under a fake, never-authenticated org would satisfy
  a REAL, unrelated victim org's DR-failover approval precondition. A
  real, temporary (deleted-after-run) HTTP test proved both halves live:
  `POST /api/incidents` with a fabricated `org_id` returned a real `HTTP
  201`, and that row then let a real victim org's
  `PATCH /api/approval_dr_failover/:id` succeed (`HTTP 200`, real audit
  log + webhook effects) with zero real relationship between the two
  orgs.

  This pass adds `Xaas.Operations.Checks.ActorOrgMatches` (see that
  module's own moduledoc), wires it into `:create`/`:update` in place of
  `authorize_if(always())`, adds `incidents` to `ResolveOrgActor`'s
  `@tenant_scoped_path_segments`, and adds a matching `org_id` filter to
  `ApprovalDrFailoverRequiresOpenIncident`'s own query so the escalation
  path is closed from both ends.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, explicit
    # carve-outs only, never allow-all. Ported access shape from
    # platform-console's real route comments (GET: any authenticated
    # member; POST/PATCH: owner-role-gated) -- xaas has no per-org role
    # model of its own yet (see docs/ASH-MIGRATION-PLAN.md Phase 5), so
    # both read and write are gated the same way every other
    # internal-api-surfaced resource in this codebase is: the
    # router-level KanbanWeb.Plugs.RequireInternalApiToken Bearer check,
    # not a resource-level role policy that doesn't exist yet.
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Updated seventeenth pass: no longer a bare `authorize_if(always())`
    # -- both now real-check `Xaas.Operations.Checks.ActorOrgMatches` (the
    # actor's `X-Org-Id`-resolved org must match this incident's real
    # `org_id`). See that module's moduledoc for the real, live-HTTP-proven
    # cross-org escalation this closes.
    bypass action(:create) do
      authorize_if(Xaas.Operations.Checks.ActorOrgMatches)
    end

    bypass action(:update) do
      authorize_if(Xaas.Operations.Checks.ActorOrgMatches)
    end

    policy always() do
      forbid_if(always())
    end
  end

  graphql do
    type(:incident)
  end

  json_api do
    type("incidents")

    routes do
      base("/incidents")
      get(:read)
      index(:read)
      post(:create)
      patch(:update)
    end
  end

  postgres do
    table("incidents")
    repo(Xaas.Repo)
  end

  actions do
    defaults([:read])

    create :create do
      description("Open a real incident, matching platform-console's incidents row shape.")

      accept([
        :org_id,
        :title,
        :description,
        :severity,
        :region,
        :status,
        :opened_at
      ])
    end

    update :update do
      description(
        "Annotate/resolve/postmortem an existing incident -- matches platform-console's " <>
          "POST /api/incidents (root_cause/severity/org annotation) and PATCH " <>
          "/api/incidents/[id]/postmortem (root_cause/remediation/status) folded onto one action."
      )

      require_atomic?(false)

      validate(Xaas.Operations.Validations.IncidentResolvedRequiresResolvedAt)

      accept([
        :title,
        :description,
        :severity,
        :status,
        :resolved_at,
        :postmortem_root_cause,
        :postmortem_remediation,
        :postmortem_status
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Real payload fields, matching platform-console's POST /api/incidents
    # body (id/rootCause/severity/orgId) plus lib/incidents.ts's Incident
    # interface (componentId -> title/description here, since xaas has no
    # component roster; startedAt/resolvedAt -> opened_at/resolved_at;
    # status).
    attribute :org_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :description, :string do
      public?(true)
    end

    attribute :severity, :incident_severity do
      # Real bug found and fixed: :string doesn't support a `one_of`
      # constraint (that's for :atom-backed types) -- real
      # Ash.Type.Enum, same pattern as the project's other enums.
      allow_nil?(false)
      default(:minor)
      public?(true)
    end

    # xaas-specific: the region this incident is scoped to, which is what
    # ApprovalDrFailoverRequiresOpenIncident matches against
    # ApprovalDrFailover.from_region. Not present in platform-console's
    # model (that app is single-cluster/component-scoped, not
    # multi-region).
    attribute :region, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :incident_status do
      # Real bug found and fixed: :string doesn't support a `one_of`
      # constraint -- real Ash.Type.Enum, same pattern as :severity above.
      allow_nil?(false)
      default(:open)
      public?(true)
    end

    attribute :opened_at, :utc_datetime do
      allow_nil?(false)
      public?(true)
    end

    attribute :resolved_at, :utc_datetime do
      public?(true)
    end

    # Real postmortem fields, folded from platform-console's separate
    # lib/postmortems.ts store onto this row (see moduledoc). Mirrors
    # PATCH /api/incidents/[id]/postmortem's VALID_PATCH_KEYS
    # (rootCause/remediation/status) plus that route's own "final" state.
    attribute :postmortem_root_cause, :string do
      public?(true)
    end

    attribute :postmortem_remediation, :string do
      public?(true)
    end

    attribute :postmortem_status, :incident_postmortem_status do
      # Real bug found and fixed: :string doesn't support a `one_of`
      # constraint -- real Ash.Type.Enum, same fix as :severity/:status.
      default(:draft)
      public?(true)
    end

    timestamps()
  end
end
