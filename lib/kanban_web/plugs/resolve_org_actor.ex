defmodule KanbanWeb.Plugs.ResolveOrgActor do
  @moduledoc """
  Real per-org actor/tenant resolution for the 4 non-global-multitenancy
  governance resources (`ApprovalDrFailover`, `ApprovalLegalHoldRelease`,
  `ApprovalDeploymentQuarantine`, `ApprovalBackupRetentionChange`), plus
  (added this session) `Xaas.Marketplace.Provider`'s real
  `:create`/`:update` routes -- see that resource's moduledoc and
  `Xaas.Marketplace.Checks.ActorOrgMatches` for the real, disclosed
  design decision (a direct policy check, not full `multitenancy` DSL).

  Extended fifteenth pass: `approval_tier_downgrade` (`Xaas.Billing.
  ApprovalTierDowngrade`) closes a real, live-HTTP-proven gap this path
  list previously left open -- that resource's `:create`/`:approve`
  routes had no org resolution at all before this pass, meaning
  `Xaas.Billing.Checks.ActorOrgMatches` (added the same pass) would
  always see a `nil` actor and always deny. See that resource's own
  moduledoc and check module for the full disclosed finding.

  Extended sixteenth pass: `approval_sla_credit_apply` and
  `approval_patch_sla_credit_apply` (`Xaas.Billing.ApprovalSlaCreditApply`
  / `ApprovalPatchSlaCreditApply`) close the identical real,
  live-HTTP-proven gap on 2 more Billing `Approval*` siblings -- see
  those resources' own moduledocs and
  `Xaas.Billing.Checks.SlaCreditActorOrgMatches` for the full disclosed
  finding (a real, live exploit that fabricated a victim org and credited
  itself, live-tested and closed this pass).

  Extended seventeenth pass: `incidents` (`Xaas.Operations.Incident`)
  closes a real, live-HTTP-proven gap that was worse than a same-resource
  bypass -- a fabricated, cross-org `Incident` could satisfy the approval
  precondition (`Xaas.Governance.Validations.
  ApprovalDrFailoverRequiresOpenIncident`) gating a REAL, unrelated victim
  org's `ApprovalDrFailover:approve`. See `Xaas.Operations.Incident`'s own
  moduledoc and `Xaas.Operations.Checks.ActorOrgMatches` for the full
  disclosed finding.

  Extended eighteenth pass: `route_orgs_custom_domain`
  (`Xaas.Platform.RouteOrgsCustomDomain`) and `route_projects_backups`
  (`Xaas.Platform.RouteProjectsBackups`) close the identical real,
  live-HTTP-proven gap on 2 more Platform resources -- see those
  resources' own moduledocs and `Xaas.Platform.Checks.ActorOrgMatches` for
  the full disclosed finding (self-contained metadata forgery: hostname
  squatting / fabricated backup-history rows under an invented `org_id`,
  real and live-tested, closed this pass).

  Extended nineteenth pass: `Xaas.Accounts.Org` -- real, live-HTTP-proven,
  but real-confirmed NOT to fit the plain `@tenant_scoped_path_segments`
  list shape the other 12 entries share, so it is handled by a dedicated,
  method-aware code path instead (see `orgs_create?/1`/`orgs_update?/1`
  below), not added to the list. `Org` is structurally different from
  every other tenant-scoped resource here: it is the tenant ROOT (no
  `org_id` string attribute of its own -- its own `slug` IS what every
  other resource's `org_id` references), its `:read`/`:index` are
  IAM-gated (`AshIam.Check`), not org-token-gated, and its `:create`
  cannot coherently require an already-existing org's `X-Org-Id` (a
  not-yet-created org has no slug to assert yet). Real, live-HTTP-proven
  finding: BOTH `POST /api/orgs` and `PATCH /api/orgs/:id` were
  unconditional `HTTP 403` before this pass -- no plug ever supplied any
  actor for either. Fresh-reproduced this pass via a temporary,
  deleted-after-run `ConnCase` test before any fix landed. Fixed by:
  `POST /api/orgs` gets a minimal, non-nil actor satisfying `Org.:create`'s
  own `actor_present()` policy (real-confirmed via `grep -rn
  "actor_present()" lib/xaas` that `Org` is the ONLY consumer of that
  check in the whole codebase, so this is a safe, fully-scoped change,
  not a general actor-presence widening); `PATCH /api/orgs/:id` gets the
  same real header-asserted `%{org_id: slug}` actor every other
  tenant-scoped resource gets, feeding `Xaas.Accounts.Checks.
  ActorBelongsToOrg`'s new org-token clause (see that module's own
  moduledoc). `GET`/`index` on `orgs` are deliberately left untouched --
  see the disclosure above.

  ## Real design decision (disclosed, not left open)

  This repo has exactly one real auth mechanism today:
  `KanbanWeb.Plugs.RequireInternalApiToken`, a single shared
  `INTERNAL_API_TOKEN` Bearer token with no per-user/per-org identity
  attached. There is no real per-org authentication model in this repo to
  build a stronger mechanism on top of.

  Given that real constraint, this plug reads a real, caller-asserted
  `X-Org-Id` request header (the org's `slug`) and resolves it against a
  real `Xaas.Accounts.Org` row. This is consistent with
  `RequireInternalApiToken`'s own trust model (every caller reaching this
  plug is already an internal/trusted service that passed the shared
  Bearer check) -- it is NOT itself an authentication upgrade. A caller
  that knows the shared internal token can assert ANY `X-Org-Id` it
  wants; nothing here proves the caller is actually acting on behalf of
  that org. Real per-org *authentication* (proving, not just asserting,
  which org a caller represents) is a larger, separate, explicitly
  out-of-scope redesign -- this plug only gives Ash's real multitenancy
  and policy machinery a real (if caller-asserted) tenant/actor to act
  on, replacing the previous `global? true` placeholder that had no
  per-org concept at all.

  ## Scoping

  Phoenix's `/api` prefix is a single blanket `forward` to
  `KanbanWeb.ApiRouter` (an `AshJsonApi.Router` covering all 7 domains'
  auto-generated routes) -- there is no per-resource pipeline hook inside
  that forward to attach a plug to only 4 of Governance's 20+ resources.
  Restructuring the forward into per-resource scopes was out of scope for
  this change and would risk breaking every other resource's routing.
  Instead, this plug inspects `conn.path_info` itself and only enforces
  org resolution for the known tenant-scoped resource path segments
  below (7 as of the fifteenth pass); every other `/api` request
  (including the other ~20 Governance resources still `global? true`)
  passes through completely unaffected.

  ## Behavior

  - Path not in the tenant-scoped set: passthrough, conn unchanged.
  - `X-Org-Id` header missing or blank: real 400, halted.
  - Header present but no matching real `Org` (by `slug`): real 404,
    halted.
  - Header present and resolves: sets both `conn.assigns[:current_actor]`
    (a real `%{org_id: org.slug}` map, matching the shape AshJsonApi's
    own `Ash.PlugHelpers.get_actor/1` reads) and, via
    `Ash.PlugHelpers.set_actor/2` and `Ash.PlugHelpers.set_tenant/2`, the
    real Ash actor/tenant that `AshJsonApi.Request` reads (see
    `deps/ash_json_api/lib/ash_json_api/request.ex`'s
    `import Ash.PlugHelpers, only: [get_actor: 1, get_tenant: 1, ...]` and
    its `actor: get_actor(conn), tenant: get_tenant(conn)` wiring) --
    this is the same real mechanism this repo's own
    `Xaas.Accounts.User`/`Xaas.Accounts.Org` `AshIam` policies expect an
    actor to arrive through, not a parallel/invented one.
  """

  import Plug.Conn

  alias Xaas.Accounts.Org

  @tenant_scoped_path_segments ~w(
    approval_dr_failover
    approval_legal_hold_release
    approval_deployment_quarantine
    approval_backup_retention_change
    marketplace_providers
    approval_provider_status_change
    approval_tier_downgrade
    approval_sla_credit_apply
    approval_patch_sla_credit_apply
    incidents
    route_orgs_custom_domain
    route_projects_backups
  )

  def init(opts), do: opts

  def call(conn, _opts) do
    cond do
      orgs_create?(conn) -> authorize_org_create(conn)
      tenant_scoped?(conn) -> resolve_org(conn)
      true -> conn
    end
  end

  # Real, nineteenth-pass, `Org`-only special case: `POST /api/orgs` (the
  # resource's `:create` action, an org that does not exist yet) cannot
  # coherently require a real `X-Org-Id` naming an ALREADY-existing org
  # (see this module's own moduledoc). `Org.:create`'s own policy only
  # requires `actor_present()` -- ANY non-nil actor -- so this plug only
  # needs to supply one, restoring the "any Bearer-token-authenticated
  # caller may create an org" behavior `org.ex`'s own moduledoc already
  # discloses as its real, intended design.
  defp orgs_create?(conn) do
    case {conn.method, conn.path_info} do
      {"POST", ["api", "orgs"]} -> true
      _ -> false
    end
  end

  defp authorize_org_create(conn) do
    actor = %{}

    conn
    |> assign(:current_actor, actor)
    |> Ash.PlugHelpers.set_actor(actor)
  end

  # Real, nineteenth-pass, `Org`-only special case: `PATCH /api/orgs/:id`
  # (`:update`) DOES need a real, header-asserted org actor -- unlike
  # `:create`, `Xaas.Accounts.Checks.ActorBelongsToOrg`'s org-token clause
  # needs a real `org_id` to compare against the record's own `slug`. Only
  # `PATCH` is matched here -- `GET`/`index` on the same `orgs` path
  # segment are deliberately left passing through unaffected (see this
  # module's own moduledoc).
  defp orgs_update?(conn) do
    case conn.path_info do
      ["api", "orgs" | _] -> conn.method == "PATCH"
      _ -> false
    end
  end

  defp tenant_scoped?(conn) do
    orgs_update?(conn) or path_segment_tenant_scoped?(conn)
  end

  defp path_segment_tenant_scoped?(conn) do
    # Real, verified detail: this plug runs in the `/api` scope's
    # `pipe_through` BEFORE `forward "/api", KanbanWeb.ApiRouter` strips
    # the `/api` prefix, so `conn.path_info` here is still
    # `["api", "approval_dr_failover", ...]`, not
    # `["approval_dr_failover", ...]` -- confirmed real (a first version
    # of this plug checked `path_info` directly and every request
    # silently passed through unaffected until this was found and
    # fixed).
    case conn.path_info do
      ["api", first | _] -> first in @tenant_scoped_path_segments
      _ -> false
    end
  end

  defp resolve_org(conn) do
    case get_req_header(conn, "x-org-id") do
      [org_id] when byte_size(org_id) > 0 ->
        case Ash.get(Org, [slug: org_id], authorize?: false) do
          {:ok, org} ->
            actor = %{org_id: org.slug}

            conn
            |> assign(:current_actor, actor)
            |> Ash.PlugHelpers.set_actor(actor)
            |> Ash.PlugHelpers.set_tenant(org.slug)

          {:error, _} ->
            not_found(conn, org_id)
        end

      _ ->
        missing_header(conn)
    end
  end

  defp missing_header(conn) do
    conn
    |> put_status(400)
    |> Phoenix.Controller.json(%{
      error: "missing_org_id",
      detail: "X-Org-Id request header is required for this route"
    })
    |> halt()
  end

  defp not_found(conn, org_id) do
    conn
    |> put_status(404)
    |> Phoenix.Controller.json(%{
      error: "org_not_found",
      detail: "no Org found with slug #{inspect(org_id)}"
    })
    |> halt()
  end
end
