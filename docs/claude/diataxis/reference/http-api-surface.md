# HTTP API Surface Reference

Complete, current enumeration of xaas's real HTTP surface: every mounted router scope,
every resource with a real `json_api do routes do ... end end` block, the real auth gates,
and the plain-JSON controller endpoints. Originally verified 2026-08-20; fully re-verified
against `lib/xaas_web/router.ex`, `lib/xaas_web/api_router.ex`,
`lib/xaas_web/internal_api_router.ex`, and grep sweeps over `lib/xaas/**/*.ex`
(`base("/`, route verbs, `routes do`) on 2026-09-22.

## Router topology

`lib/xaas_web/router.ex` (re-verified 2026-09-22) defines these scopes:

- **Browser** (`pipe_through :browser`): `GET /` (`PageController.home`) and the
  `GET /next-read` Next Read LiveView.
- **`/webhooks`** (`:api` only — deliberately NOT behind the internal-api token, because
  Stripe is the caller and cannot supply it): `POST /webhooks/stripe`, authenticated by
  Stripe-signature verification inside `XaasWeb.StripeWebhookController`.
- **`/internal-api` controller scope** (`[:api, :require_internal_api_token]`, registered
  *before* the catch-all forward): `capability_liveness_regressions`, `ocel_summary`,
  `prometheus/query`, `health`, `rpc/run`, `rpc/validate`, `execution/hooks/:event`,
  `execution/mcp`, `execution/runs`, `execution/epochs/:epoch_id/receipts`.
- **`/mcp`** (`[:api, :require_internal_api_token, :resolve_org_actor,
  :audit_mcp_tool_call]`): generated `XaasWeb.McpScope.mount()` forwarding to
  `AshAi.Mcp.Router` — read-only Library tools, one audit row per request.
- **`/a2a`** (`[:api, :require_internal_api_token]`): `forward /zoe-event` to
  `XaasWeb.A2A.ZoeEventPlug` (registered before the catch-all), then `forward /` to
  `A2A.Plug` with `XaasWeb.A2A.NextReadUserAgent`.
- **`/api/workbench`** (`[:api, :require_internal_api_token]`, before the `/api` forward):
  `GET /ggen/health` and `POST /ggen` — the CONSTRUCT-only GGen workbench forward to a
  private Fly worker; no shell or cloud actuation authority.
- **`/internal-api/sparql`** (`[:api, :require_internal_api_token]`, before the forward):
  reverse proxy to the Ontop R2RML SPARQL endpoint (`XaasWeb.OntopProxyPlug`).
- **`forward /internal-api`** → `XaasWeb.InternalApiRouter`
  (`[:internal_api, :require_internal_api_token, :set_internal_api_system_actor]`).
- **`forward /api`** → `XaasWeb.ApiRouter`
  (`[:internal_api, :require_internal_api_token, :resolve_org_actor,
  :set_internal_api_system_actor]`).
- **Dev-only** (`Application.compile_env(:xaas, :dev_routes)`): LiveDashboard
  `/dev/dashboard`, Swoosh mailbox `/dev/mailbox`, the autofde-lab LiveView
  `/dev/dashboards/autofde-lab`, and AshAdmin `/admin`.

Three ordering facts about these scopes are load-bearing:

1. Every plain-JSON controller route under `/internal-api` (including the execution-fabric
   and SPARQL routes) is registered **before** `forward "/internal-api"`. A Phoenix
   `forward` matches every sub-path under its prefix, so declaring it first would have
   shadowed them (confirmed by a real 404 from `AshJsonApi.Router`'s own `no_route_found`
   before the router was reordered).
2. Both `/internal-api` and `/api` are gated by the same `require_internal_api_token`
   pipeline. This plug did not exist on either prefix originally — added after an adversarial
   review found both real-200'd for any anonymous client.
3. `/a2a/zoe-event` is registered before the `/a2a` catch-all forward for the same
   shadowing reason.

## Auth: `XaasWeb.Plugs.RequireInternalApiToken`

Defined in `lib/xaas_web/plugs/require_internal_api_token.ex`. Applies to every route under
`/internal-api` and `/api` (both the two controller endpoints and both `AshJsonApi.Router`
forwards).

- Reads the real env var `INTERNAL_API_TOKEN` on every request (same pattern as
  `DEV_DB_PASSWORD`/`CLOAK_KEY` elsewhere in this repo — never hardcoded, never committed).
- **Fail closed**: if `INTERNAL_API_TOKEN` is unset on the server, every request is rejected
  with `503` and body `{"error": "internal_api_misconfigured", "detail": "INTERNAL_API_TOKEN is not set on the server"}` — not silently allowed through.
- If the var is set, the request must carry `Authorization: Bearer <token>` where `<token>`
  matches via `Plug.Crypto.secure_compare/2` (constant-time comparison). Missing header, wrong
  scheme, or a mismatched token all return `401` with
  `{"error": "unauthorized", "detail": "missing or invalid Bearer token"}`.
- For org-carrying DB tokens the plug also attaches `conn.assigns[:current_org]`, which the
  execution-fabric `runs`/`receipts` endpoints use for org scoping (a legacy shared-token or
  org-less caller is refused with a typed 403 on the org-scoped surfaces).

Two more pipelines compose after the token gate (both defined in `router.ex`):

- `:set_internal_api_system_actor` (`XaasWeb.Plugs.SetInternalApiSystemActor`, XAAS-2602) —
  supplies the real system-authority actor (`Xaas.SystemAuthority.new(:internal_api)`) for
  the SERVICE-BOUNDARY resources whose mutations are guarded by
  `Xaas.Checks.SystemActor`. Mounted on both AshJsonApi forwards; runs *after* the Bearer
  check and never overrides an already-resolved org actor.
- `:audit_mcp_tool_call` (`XaasWeb.Plugs.AuditMcpToolCall`) — writes one real
  `Xaas.Operations.AuditLogEntry` row per `/mcp` HTTP request so unscoped Library reads are
  observable. Mounted on `/mcp` only, deliberately not on `/api` or `/internal-api`.
  Known asymmetry (open work order): this audit covers `/mcp` but NOT
  `/internal-api/execution/mcp`.

Example real request:

```bash
curl -H "Authorization: Bearer $INTERNAL_API_TOKEN" \
  http://localhost:4000/internal-api/capability_liveness_regressions
```

## `/api` — `XaasWeb.ApiRouter`

`lib/xaas_web/api_router.ex` mounts `AshJsonApi.Router` for 7 domains:
`Xaas.Accounts`, `Xaas.Billing`, `Xaas.Governance`, `Xaas.Ledger`, `Xaas.Marketplace`,
`Xaas.Operations`, `Xaas.Platform` — of the 13 domains configured in `config/config.exs`
(Library, Coupling, Generation, Ocel, TemporalMemory, and Ultracode are not mounted here;
Library is served through the `/mcp` tools instead). Mounting a domain does not itself
expose anything — only resources that declare their own
`json_api do routes do ... end end` block are actually reachable.

Recounted 2026-09-22 by the same grep method this doc has used before
(`grep -rln 'base("/'` + route-verb sweeps over `lib/xaas/**/*.ex`):

- **62** resources repo-wide declare a real `base(...)` path: **56 on `/api`**, **1 on
  `/internal-api`** (`capability_liveness_receipts`), and **5 Library resources whose routes
  are declared but whose domain is not mounted in either AshJsonApi router** (reachable via
  `/mcp` tools and AshAdmin, not raw JSON:API).
- **45 of the 56 `/api` resources expose a real mutation route** (`post(...)`,
  `patch(...)`, or `delete(...)` beyond `get`/`index`; routes use paren-call style). The
  remaining 11 are read-only. `docs/ASH-MIGRATION-PLAN.md` Phase 5 item 2 (a real
  customer-facing mutation surface) is accordingly **substantially addressed**, not fully
  resolved — the deliberately-unwired sensitive resources (`Ledger.Balance`/`Account`/
  `Transfer`, `Accounts.User`/`Token`) still have zero route regardless of mutation status,
  by the same deliberate design this doc's own "Deliberately unwired" section documents
  below.
- Mutation verbs now go beyond the original `post(:create)`/`patch(:approve)`/
  `patch(:update)` pattern — e.g. `post(:issue)`/`patch(:revoke)` on
  `Xaas.Governance.AuditExportToken`, `patch(:remediate)` on
  `Xaas.Governance.PentestFinding`, `patch(:record_attempt)` on
  `Xaas.Platform.WebhookDelivery`, and `delete(:destroy)` on Platform resources.

### Wired resources (real `base` path, real domain, both routed under `/api`)

Accounts (`lib/xaas/accounts/`):

| Base path | Resource module |
|---|---|
| `/orgs` | `Xaas.Accounts.Org` (`get`/`index`/`post(:create)`/`patch(:update)`) |

`Accounts.User` and `Accounts.Token` remain deliberately unwired (see below); `Org` is the
one Accounts resource with a real public surface.

Billing (`lib/xaas/billing/`):

| Base path | Resource module |
|---|---|
| `/approval_invoice_reconciliation_approve` | `Xaas.Billing.ApprovalInvoiceReconciliationApprove` |
| `/approval_patch_sla_credit_apply` | `Xaas.Billing.ApprovalPatchSlaCreditApply` |
| `/approval_pricing_override` | `Xaas.Billing.ApprovalPricingOverride` |
| `/approval_quota_override` | `Xaas.Billing.ApprovalQuotaOverride` |
| `/approval_sla_credit_apply` | `Xaas.Billing.ApprovalSlaCreditApply` |
| `/approval_tier_downgrade` | `Xaas.Billing.ApprovalTierDowngrade` |
| `/billing_subscriptions` | `Xaas.Billing.Subscription` |

Marketplace (`lib/xaas/marketplace/`):

| Base path | Resource module |
|---|---|
| `/marketplace_providers` | `Xaas.Marketplace.Provider` (`get`/`index`/`post(:create)`/`patch(:update)`; `:status` is not accepted by the public update — lifecycle goes through the receipted actuation path) |
| `/approval_provider_status_change` | `Xaas.Marketplace.ApprovalProviderStatusChange` (`post(:create)`/`patch(:approve)`) |

Governance (`lib/xaas/governance/`):

| Base path | Resource module |
|---|---|
| `/approval_backup_retention_change` | `Xaas.Governance.ApprovalBackupRetentionChange` |
| `/approval_break_glass_justification_review` | `Xaas.Governance.ApprovalBreakGlassJustificationReview` |
| `/approval_change_of_control_notify` | `Xaas.Governance.ApprovalChangeOfControlNotify` |
| `/approval_cmek_key_binding` | `Xaas.Governance.ApprovalCmekKeyBinding` |
| `/approval_compliance_rotation_block` | `Xaas.Governance.ApprovalComplianceRotationBlock` |
| `/approval_denied_party_override` | `Xaas.Governance.ApprovalDeniedPartyOverride` |
| `/approval_deployment_quarantine` | `Xaas.Governance.ApprovalDeploymentQuarantine` |
| `/approval_dr_failover` | `Xaas.Governance.ApprovalDrFailover` |
| `/approval_dsar_erasure` | `Xaas.Governance.ApprovalDsarErasure` |
| `/approval_environment_promote` | `Xaas.Governance.ApprovalEnvironmentPromote` |
| `/approval_export_subscription_update` | `Xaas.Governance.ApprovalExportSubscriptionUpdate` |
| `/approval_freeze_override` | `Xaas.Governance.ApprovalFreezeOverride` |
| `/approval_geofence_exception_grant` | `Xaas.Governance.ApprovalGeofenceExceptionGrant` |
| `/approval_insurance_policy_update` | `Xaas.Governance.ApprovalInsurancePolicyUpdate` |
| `/approval_le_request_respond` | `Xaas.Governance.ApprovalLeRequestRespond` |
| `/approval_legal_hold_release` | `Xaas.Governance.ApprovalLegalHoldRelease` |
| `/approval_org_delete` | `Xaas.Governance.ApprovalOrgDelete` |
| `/approval_pentest_finding_resolve` | `Xaas.Governance.ApprovalPentestFindingResolve` |
| `/approval_personnel_attestation_record` | `Xaas.Governance.ApprovalPersonnelAttestationRecord` |
| `/approval_source_escrow_snapshot` | `Xaas.Governance.ApprovalSourceEscrowSnapshot` |
| `/approval_sso_role_mapping_update` | `Xaas.Governance.ApprovalSsoRoleMappingUpdate` |
| `/approval_subprocessor_registry_update` | `Xaas.Governance.ApprovalSubprocessorRegistryUpdate` |
| `/approval_vendor_offboarding_attestation_issue` | `Xaas.Governance.ApprovalVendorOffboardingAttestationIssue` |
| `/audit_export_tokens` | `Xaas.Governance.AuditExportToken` (`post(:issue)`/`patch(:revoke)`) |
| `/data_destruction_certificate_issue` | `Xaas.Governance.DataDestructionCertificateIssue` |
| `/freeze_window` | `Xaas.Governance.FreezeWindow` |
| `/pentest_findings` | `Xaas.Governance.PentestFinding` (`post(:create)`/`patch(:remediate)`) |

Operations (`lib/xaas/operations/`, mounted via `/api` — separate from the `/internal-api`
routes below):

| Base path | Resource module |
|---|---|
| `/approval_castle_verb_schedule` | `Xaas.Operations.ApprovalCastleVerbSchedule` |
| `/approval_k8s_fault_remediate_suggest` | `Xaas.Operations.ApprovalK8sFaultRemediateSuggest` |
| `/audit_log_entries` | `Xaas.Operations.AuditLogEntry` (read-only) |
| `/castle_verb_fortune5_requirements` | `Xaas.Operations.CastleVerbFortune5Requirements` |
| `/castle_verb_inventory_components` | `Xaas.Operations.CastleVerbInventoryComponents` |
| `/castle_verb_inventory_goals` | `Xaas.Operations.CastleVerbInventoryGoals` |
| `/incidents` | `Xaas.Operations.Incident` (`post(:create)`/`patch(:update)`) |
| `/project_measurement` | `Xaas.Operations.ProjectMeasure.Measurement` (one GET-only observation route, per the ApiRouter moduledoc) |
| `/route_castle_deploy` | `Xaas.Operations.RouteCastleDeploy` |
| `/route_castle_run` | `Xaas.Operations.RouteCastleRun` |
| `/route_castle_schedule` | `Xaas.Operations.RouteCastleSchedule` |
| `/route_castle_sunset` | `Xaas.Operations.RouteCastleSunset` |

Platform (`lib/xaas/platform/`):

| Base path | Resource module |
|---|---|
| `/route_feature_flags` | `Xaas.Platform.RouteFeatureFlags` |
| `/route_orgs_custom_domain` | `Xaas.Platform.RouteOrgsCustomDomain` |
| `/route_projects` | `Xaas.Platform.RouteProjects` |
| `/route_projects_backups` | `Xaas.Platform.RouteProjectsBackups` |
| `/route_secrets` | `Xaas.Platform.RouteSecrets` |
| `/webhooks` | `Xaas.Platform.Webhook` (outbound webhooks; `post(:create)`/`delete(:destroy)`) |
| `/webhook_deliveries` | `Xaas.Platform.WebhookDelivery` (`post(:create)`/`patch(:record_attempt)`) |

Library (`lib/xaas/library/`) also declares five real `base(...)` routes — `/library/books`,
`/library/checkouts`, `/library/holds`, `/library/curations`,
`/library/recommendation_logs`, all read-only — but **`Xaas.Library` is not mounted in
`XaasWeb.ApiRouter` (or the internal router)**, so these are not reachable as raw JSON:API
today; the Library surface is served through the `/mcp` tools, the `/next-read` LiveView,
and AshAdmin.

The wired resources share the same DSL shape, though the route sets now vary per resource
(paren-call style throughout, re-verified 2026-09-22). Read-only resources (e.g.
`Xaas.Platform.RouteProjects`):

```elixir
json_api do
  type "..."

  routes do
    base("/route_projects")
    get(:read)
    index(:read)
  end
end
```

The maker-checker approval cluster (23 Governance + 6 Billing + 2 Operations + 1
Marketplace `Approval*` resources) uses `get(:read)`/`index(:read)`/`post(:create)`/
`patch(:approve)`; the remaining wired resources add verbs matching their own semantics
(`delete(:destroy)`, `patch(:update)`, `patch(:revoke)`, `patch(:remediate)`,
`patch(:record_attempt)`, `post(:issue)`). Every resource above is real-reachable at
`GET /api/<base>` (index) and `GET /api/<base>/:id` (get), both requiring the
`Authorization: Bearer` header above.

### First real mutation route (issue #20): `Xaas.Billing.ApprovalPricingOverride`

`Xaas.Billing.ApprovalPricingOverride` additionally exposes a real `PATCH
/api/approval_pricing_override/:id` route on a new `:approve` update action — the first
real customer-facing mutation route in the repo, proving the pattern issue #20 asks for
before generalizing to other resources:

```elixir
json_api do
  type "approval_pricing_override"

  routes do
    base "/approval_pricing_override"
    get :read
    index :read
    patch :approve
  end
end

actions do
  update :approve do
    accept [:approved_by]
    require_atomic? false
    change Xaas.Billing.Changes.ApprovalPricingOverrideApprove
    validate Xaas.Billing.Validations.ApprovalPricingOverrideRequiresApprover
  end
end

policies do
  bypass action(:approve) do
    authorize_if always()
  end
end
```

Real business rule (`Xaas.Billing.Validations.ApprovalPricingOverrideRequiresApprover`):
`approved_by` must be present, and must differ from `requested_by` (a requester cannot
approve their own pricing-override request). Both attributes needed `public? true` added
for `AshJsonApi` to serialize them at all — without it, every read route on this resource
was already silently returning `"attributes": {}` (found while building this feature, not
yet checked across the other 43 read-only resources).

Real Chicago-style coverage: `test/xaas_web/controllers/approval_pricing_override_controller_test.exs`
— real Postgres-backed accept case, plus the two real reject cases (missing approver, self-
approval) and the real no-token-401 case, per this repo's testing discipline of asserting the
reject path, not just the accept path.

### Second real mutation route (issue #20): `Xaas.Governance.ApprovalBackupRetentionChange`

Ported from platform-console's real `PUT /api/orgs/[id]/backup-policy` maker-checker flow
(`docs/ASH-MIGRATION-PLAN.md`'s recommended next step: reimplement the governance/owner/
compliance route cluster, which already has same-named Ash resource stubs). Real `PATCH
/api/approval_backup_retention_change/:id` route on a new `:approve` update action:

```elixir
actions do
  create :create do
    accept [:org_id, :requested_by, :requested_retention_days]
  end

  update :approve do
    accept [:approved_by]
    require_atomic? false
    change Xaas.Governance.Changes.ApprovalBackupRetentionChangeApprove
    validate Xaas.Governance.Validations.ApprovalBackupRetentionChangeRequiresApprover
  end
end

policies do
  bypass action(:approve) do
    authorize_if always()
  end
end
```

Real business rule (`ApprovalBackupRetentionChangeRequiresApprover`, matching
platform-console's own stated reasoning — "a retention change is a real
compliance-evidence-affecting decision... always requires a second, distinct owner-role
approver"): `approved_by` must be present and must differ from `requested_by`. Real attributes
`org_id` and `requested_retention_days` were added (previously `requested_by`/`approved_by`
only); a real migration (`priv/repo/migrations/20260820235809_add_backup_retention_change_columns.exs`)
adds the two columns.

**Update, same session — real tier-range validation, real ledger-backed revenue, real kind
proof.** The user rejected "just an endpoint" and asked for a Chicago-style test proving the
feature actually generates revenue, with the explicit framing that xaas is meant to be its own
payment processor, not a Stripe passthrough. What was added:

- A real `tier` attribute (`Xaas.Governance.Types.ProjectTier`, values `:starter`/`:pro`/
  `:enterprise`, ported verbatim from platform-console's `ProjectTier`) and a real per-tier
  `RETENTION_RANGE` validation (`ApprovalBackupRetentionChangeWithinTierRange`, also ported
  verbatim: starter 1–7 days, pro 7–90, enterprise 30–2555) — a real 400-shaped rejection on
  `:create`, matching platform-console's own hard-reject behavior exactly.
- **Honest disclosure**: platform-console has **no fee** for retention overage — it only
  rejects out-of-range requests. Porting a "retention overage fee" as if it came from
  platform-console would have been fabricating a rule that doesn't exist there.
- Real, disclosed **new** business logic instead (`ApprovalBackupRetentionChangeChargeOverage`):
  on `:approve`, if the approved retention exceeds the tier's default
  (`starter: 7, pro: 30, enterprise: 365`), a real `Xaas.Ledger.Transfer` moves a real (if
  placeholder-priced, $0.10/day-over-default, stated plainly as invented not commercially
  validated) fee from the org's real `Xaas.Ledger.Account` to a fixed platform-revenue
  account, inside the `:approve` action's own transaction.
- Also added a real `post :create` route (previously only `create` via internal
  `Ash.Changeset.for_create` calls existed) — needed so the feature is exercisable over real
  HTTP end to end, not just via internal Ash calls.
- **Real bug found and fixed along the way**: `Xaas.Ledger.EventLog`'s `record_id_type`
  defaulted to `:uuid`, but the event log is shared by `Xaas.Ledger.Account` (uuid_v7 PK) and
  `Xaas.Ledger.Transfer` (`AshDoubleEntry.ULID` PK, a ULID string). The first real
  `Xaas.Ledger.Transfer.transfer` call ever exercised in this repo failed validating a real
  ULID against `:uuid`. Fixed by setting `record_id_type :string`
  (`lib/xaas/ledger/event_log.ex`), a real migration applied.
- **Real infra gaps found and fixed against the live `kind-xaas` cluster**: the live
  `xaas-secrets` Secret never had a real `INTERNAL_API_TOKEN` (was still the literal
  placeholder string) or `ONETIME_REVOKE_KEY` at all (missing from both the live secret and
  the example template — `config/runtime.exs` raises on boot without it) — both generated for
  real and applied; the live pod crash-looped on `ONETIME_REVOKE_KEY` and then OOM-killed
  during `mix.Release.migrate()` at the deployment's original 512Mi limit (bumped to 1Gi).
- **Real end-to-end proof against the live deployment**, not the local sandbox:
  `test/e2e/kind_deployment_test.exs` (tagged `:kind`, excluded by default like `:stress`) —
  real `Req` HTTP calls (`POST create` → `PATCH approve`) against the live `kind-xaas` pod via
  a real `kubectl port-forward`, then a real `kubectl exec <postgres-pod> -- psql` readback
  against the live Postgres confirming the org's real ledger balance moved by exactly
  `-$6.00` (60 real overage days × the $0.10 placeholder rate). Deliberately does **not** add
  any HTTP route to `Xaas.Ledger.*` — those 3 resources stay unwired per this repo's
  never-blindly-touch-sensitive-resources discipline; the balance readback goes through a
  direct Postgres query instead.

Real Chicago-style coverage:
`test/xaas_web/controllers/approval_backup_retention_change_controller_test.exs` — accept
case, missing-approver reject, self-approval reject, no-token 401 reject, tier-range reject,
real ledger-balance-change assertion on overage approval, real no-charge assertion when no
overage occurs. Plus `test/e2e/kind_deployment_test.exs` against the live deployment (see
above).

### Third-fifth real mutation routes (issue #20): DR failover, CMEK key binding, DSAR erasure

Continuing the governance-cluster pattern, three more resources gained real `POST`/`PATCH`
routes, each with real payload attributes ported verbatim from their platform-console
counterparts:

- **`Xaas.Governance.ApprovalDrFailover`** ↔ `POST /api/dr/initiate-failover`: real
  `org_id`/`from_region`/`to_region`/`reason`. Not ported: platform-console's runtime
  precondition that an open incident referencing `from_region` must exist — xaas has no
  Incident resource yet, honestly left undone.
- **`Xaas.Governance.ApprovalCmekKeyBinding`** ↔ `PUT /api/orgs/[id]/cmek`: real
  `org_id`/`provider` (`Xaas.Governance.Types.CmekProvider`, ported verbatim:
  `aws_kms`/`gcp_kms`/`azure_keyvault`/`vault`)/`key_ref`/`reason`. Not ported: the real
  Secrets/PVC re-annotation platform-console performs on a live key rotation — xaas has no
  live k8s-write path for this yet.
- **`Xaas.Governance.ApprovalDsarErasure`** ↔ `POST /api/privacy/request-erasure`: real
  `org_id`/`subject_email`, validated against platform-console's real `EMAIL_RE`
  (`ApprovalDsarErasureValidSubjectEmail`, ported verbatim). Not ported: `runDsarErasure`'s
  actual data deletion — xaas has no real subject-data store to erase from yet.

Each follows the same real shape as `ApprovalBackupRetentionChange`/`ApprovalPricingOverride`:
`bypass action(:create)`/`bypass action(:approve)`, a `*RequiresApprover` validation (present +
distinct-from-requester), real Chicago-style HTTP tests
(`test/xaas_web/controllers/approval_{dr_failover,cmek_key_binding,dsar_erasure}_controller_test.exs`).

### Deliberately unwired (6 resources, no `json_api` block at all)

Per `lib/xaas_web/api_router.ex`'s own moduledoc, these have **no** `routes do` block —
mounting `Xaas.Accounts` and `Xaas.Ledger` in the router above does not expose them:

- `Xaas.Ledger.Balance` (`lib/xaas/ledger/balance.ex`)
- `Xaas.Ledger.Account` (`lib/xaas/ledger/account.ex`)
- `Xaas.Ledger.Transfer` (`lib/xaas/ledger/transfer.ex`)
- `Xaas.Accounts.User` (`lib/xaas/accounts/user.ex`)
- `Xaas.Accounts.Token` (`lib/xaas/accounts/token.ex`) — holds cloaked `extra_data`
- `Xaas.Accounts.Token.RevokeNonce` (`lib/xaas/accounts/token/revoke_nonce.ex`) — token-revocation bookkeeping, same PII-adjacent design decision

Reasoning stated in the router moduledoc: the ledger resources are real double-entry financial
data needing a real access-control design (whose balance can whom see?) before any open read is
safe; `User`/`Token` are real auth/PII. Both need a real business decision, not a generic
mechanical `get :read` pass.

(`Xaas.Ledger.EventLog` is not in this exclusion list in the router moduledoc's own text, but
also has no `json_api do` block per the grep above — it is unwired the same way, just not called
out by name in that comment.)

## `/internal-api` — `XaasWeb.InternalApiRouter`

`lib/xaas_web/internal_api_router.ex` mounts `AshJsonApi.Router` for a single domain,
`Xaas.Operations`, at prefix `/internal-api`. Currently only one resource in that domain
declares a route:

```elixir
# lib/xaas/operations/capability_liveness_receipt.ex, lines 63-76
json_api do
  type "capability_liveness_receipts"

  routes do
    base "/capability_liveness_receipts"
    get :read
    index :read
  end
end
```

Reachable at `GET /internal-api/capability_liveness_receipts` and
`GET /internal-api/capability_liveness_receipts/:id` (Bearer token required), returning the
ingested MAPE-K receipt rows (see `lib/xaas/operations/capability_liveness_receipt.ex` and
`lib/mix/tasks/xaas.ingest_capability_receipts.ex` for how these rows are populated).

## Plain-JSON controller endpoints (not `AshJsonApi`, not the JSON:API envelope)

These are registered directly on `XaasWeb.Router` under `/internal-api`, ahead of the
`AshJsonApi.Router` forward (for the shadowing reason documented above), and all require the
same `Authorization: Bearer` header.

### `GET /internal-api/capability_liveness_regressions`

`XaasWeb.CapabilityRegressionsController`. Real response shape, taken from the real assertions
in `test/xaas_web/controllers/capability_regressions_controller_test.exs`:

```json
{
  "count": 1,
  "regressions": [
    {
      "capability": "some-capability-name",
      "was": { "status": "ALIVE" },
      "now": { "status": "BUILD_BROKEN" }
    }
  ]
}
```

`count` is always present; `regressions` is `[]` when no capability transitioned from a live
status to a regressed one across the ingested `capability_liveness_receipts` history (see
`lib/xaas/operations/capability_liveness_regressions.ex` for the real detection logic this
controller surfaces).

### `GET /internal-api/ocel_summary`

`XaasWeb.OcelSummaryController`. Real response shape, taken from the real assertions in
`test/xaas_web/controllers/ocel_summary_controller_test.exs`:

```json
{
  "total_events": 1,
  "by_activity": { "capability_liveness_receipt.ingest": 1 },
  "by_outcome": {},
  "log_path": ".../priv/ocel/ash-actions.ndjson"
}
```

- `total_events`: integer count of OCEL v2 events in the real NDJSON log.
- `by_activity`: map of activity name (`"<resource>.<action>"`, e.g.
  `"capability_liveness_receipt.ingest"`) to count.
- `by_outcome`: map of outcome label to count (populated only for events that recorded an
  outcome — see the `lib/xaas/telemetry/ocel_ash_emitter.ex` "stop only, no exception event"
  limitation for why failed actions may be under-represented here).
- `log_path`: absolute path to the real log file, always ending in
  `priv/ocel/ash-actions.ndjson`.

Both fields are computed by reading the real file at
`Xaas.Telemetry.OcelAshEmitter.log_path/0` — no mocked file I/O, per the test's own moduledoc.

### `GET /internal-api/prometheus/query`, `GET /internal-api/health`, `POST /internal-api/rpc/run`, `POST /internal-api/rpc/validate`

`PrometheusQueryController`, `HealthController`, and `AshTypescriptRpcController` — same
token gate, registered ahead of the catch-all forward. The `rpc/*` pair is the
AshTypescript RPC surface for the four domains declaring `AshTypescript.Rpc`
(`Xaas.Accounts`, `Xaas.Billing`, `Xaas.Marketplace`, `Xaas.Operations`).

## Execution fabric endpoints

All under `/internal-api/execution/`, behind the token gate, backed by
`Xaas.Ultracode.*` (`lib/xaas_web/controllers/execution_fabric_controller.ex`):

- `POST /internal-api/execution/mcp` — stateless MCP JSON-RPC with seven verbs:
  `claim_next`, `heartbeat`, `admit_tool`, `record_provider_event`, `close_candidate`,
  `refuse`, `actuate`. `actuate` is the only way a provider worker crosses into the admitted
  `Xaas.Actuation.run/4` DO kernel (via `Xaas.Ultracode.Lease.actuate/2`) — a wholly
  separate, narrower surface from `admit_tool`'s construction/consequence fence.
- `POST /internal-api/execution/hooks/:event` — plain-JSON PreToolUse hook surface for the
  generated provider plugin.
- `POST /internal-api/execution/runs` — org-scoped run submission: requires the request to
  have authenticated via an org-carrying `InternalApiToken` (`conn.assigns[:current_org]`);
  legacy shared-token or org-less callers get a typed 403, never a silently org-less Run.
- `GET /internal-api/execution/epochs/:epoch_id/receipts` — the lawful read path onto
  `Xaas.Ultracode.Receipt` (org-scoped for org-carrying tokens).

`/internal-api/sparql` (same scope, before the forward) reverse-proxies to the Ontop R2RML
SPARQL endpoint via `XaasWeb.OntopProxyPlug`.

## Other HTTP surfaces

- **`POST /webhooks/stripe`** — public inbound Stripe receiver, deliberately not behind the
  internal-api token (Stripe cannot supply it); authenticity is Stripe-signature
  verification inside the controller.
- **`/mcp`** — Ash AI MCP server (generated `XaasWeb.McpScope` — tool list, protocol
  version, and otp_app come from `priv/ggen_igniter/mcp_a2a/xaas-surface.ttl`; regenerate
  through that pack, do not hand-edit) exposing read-only Library tools
  (`:list_books`, `:books_by_grade_band`, `:active_curations_for_grade`), one
  `AuditLogEntry` row written per request by `XaasWeb.Plugs.AuditMcpToolCall`. Note: the
  `:resolve_org_actor` plug in this pipeline is a real no-op for `/mcp` paths (its
  tenant path-allowlist only matches `/api/...`); the actual read gate is the resources'
  `authorize_if always()` read policies — see the router's own corrected comment.
- **`/a2a`** — Agent-to-Agent server: `POST /a2a/zoe-event` (the ZOE event-simulation
  agent, authority-free SA2A-shaped trace) and `POST /a2a/` (the Next Read multi-persona
  agent). Both token-gated.
- **`GET /api/workbench/ggen/health`, `POST /api/workbench/ggen`** — CONSTRUCT-only GGen
  workbench forward to a private Fly worker; ordinary authenticated JSON, not JSON:API.
- **Browser surface** — `GET /` and the `GET /next-read` LiveView (public, browser
  pipeline). Dev-only routes (`/dev/dashboard`, `/dev/mailbox`,
  `/dev/dashboards/autofde-lab`, `/admin`) mount only under
  `Application.compile_env(:xaas, :dev_routes)`.

## See Also

- `lib/xaas_web/router.ex`, `lib/xaas_web/api_router.ex`,
  `lib/xaas_web/internal_api_router.ex` — the three real router files this doc documents
- `lib/xaas_web/plugs/require_internal_api_token.ex`,
  `lib/xaas_web/plugs/set_internal_api_system_actor.ex`,
  `lib/xaas_web/plugs/audit_mcp_tool_call.ex` — the real auth/actor/audit plugs
- `lib/xaas_web/controllers/execution_fabric_controller.ex`, `lib/xaas/ultracode/lease.ex` —
  the real execution-fabric surface and its lease-gated actuation kernel
- `lib/xaas/operations/capability_liveness_receipt.ex`,
  `lib/xaas/operations/capability_liveness_regressions.ex`,
  `lib/mix/tasks/xaas.ingest_capability_receipts.ex` — the real MAPE-K loop backing
  `/internal-api/capability_liveness_receipts` and `/internal-api/capability_liveness_regressions`
- `lib/xaas/telemetry/ocel_ash_emitter.ex` — the real OCEL v2 emitter backing `/internal-api/ocel_summary`
- `priv/ggen_igniter/mcp_a2a/xaas-surface.ttl` → `XaasWeb.McpScope` — the generated `/mcp` scope
- `docs/ASH-MIGRATION-PLAN.md` — Phase 5 item 2, the still-open decision on a real
  customer-facing mutation surface
- `test/xaas_web/controllers/capability_regressions_controller_test.exs`,
  `test/xaas_web/controllers/ocel_summary_controller_test.exs` — real Chicago-style tests this
  doc's response shapes are grounded in
