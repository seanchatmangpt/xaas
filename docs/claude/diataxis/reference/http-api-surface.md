# HTTP API Surface Reference

Complete, current enumeration of xaas's real HTTP surface: every mounted router, every
resource with a real `json_api do routes do ... end end` block, the real auth gate, and the
two plain-JSON controller endpoints. Verified by reading `lib/kanban_web/router.ex`,
`lib/kanban_web/api_router.ex`, `lib/kanban_web/internal_api_router.ex`, and grepping
`lib/xaas/**/*.ex` for `json_api do` on 2026-08-20.

## Router topology

`lib/kanban_web/router.ex` defines three real scopes:

```elixir
scope "/", KanbanWeb do
  pipe_through :browser
  get "/", PageController, :home
end

scope "/internal-api", KanbanWeb do
  pipe_through [:api, :require_internal_api_token]
  get "/capability_liveness_regressions", CapabilityRegressionsController, :index
  get "/ocel_summary", OcelSummaryController, :index
end

scope "/" do
  pipe_through [:internal_api, :require_internal_api_token]
  forward "/internal-api", KanbanWeb.InternalApiRouter
  forward "/api", KanbanWeb.ApiRouter
end
```

Two real facts about this ordering, both load-bearing:

1. The two plain-JSON controller routes under `/internal-api` are registered **before**
   `forward "/internal-api"`. A Phoenix `forward` matches every sub-path under its prefix, so
   declaring it first would have shadowed the controller routes (confirmed by a real 404 from
   `AshJsonApi.Router`'s own `no_route_found` before the router was reordered).
2. Both `/internal-api` and `/api` are gated by the same `require_internal_api_token`
   pipeline. This plug did not exist on either prefix originally — added after an adversarial
   review found both real-200'd for any anonymous client.

`AshAdmin.Router` is mounted at `/admin` and `Phoenix.LiveDashboard` at `/dev/dashboard`, both
gated by `Application.compile_env(:kanban, :dev_routes)` (dev-only; no auth plug is added for
either, per the router's own comment, since production exposure was deliberately out of scope
for this session).

## Auth: `KanbanWeb.Plugs.RequireInternalApiToken`

Defined in `lib/kanban_web/plugs/require_internal_api_token.ex`. Applies to every route under
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

Example real request:

```bash
curl -H "Authorization: Bearer $INTERNAL_API_TOKEN" \
  http://localhost:4000/internal-api/capability_liveness_regressions
```

## `/api` — `KanbanWeb.ApiRouter`

`lib/kanban_web/api_router.ex` mounts `AshJsonApi.Router` for 6 domains:
`Xaas.Accounts`, `Xaas.Billing`, `Xaas.Governance`, `Xaas.Ledger`, `Xaas.Operations`,
`Xaas.Platform`. Mounting a domain does not itself expose anything — only resources that
declare their own `json_api do routes do ... end end` block are actually reachable. Per the
router's own moduledoc, 56 of 69 real resources have that block (real-recounted 2026-08-21,
thirteenth ERRC pass, via `grep -rl "routes do" lib/xaas --include="*.ex" | wc -l`; the prior
"44 of 49" figure was stale on both the numerator and the denominator — 49 was the real
resource-surface total before the domain set grew to 69). The claim that follows was also
stale and is corrected here: **44 of those 56 now declare a real mutation route** (`post
:create`, `patch :approve`, or `patch :update`, not just `get :read`/`index :read`) —
real-recounted via the same sweep, matching the per-resource maker-checker mutation-route work
this session's own history landed (see
`docs/claude/diataxis/explanation/errc-innovation-grid.md`'s Sixth-pass update onward). Only
the remaining 12 of the 56 are still read-only. `docs/ASH-MIGRATION-PLAN.md` Phase 5 item 2 (a
real customer-facing mutation surface) is accordingly **substantially addressed**, not fully
resolved — the 5 deliberately-unwired sensitive resources (`Ledger.Balance`/`Account`/
`Transfer`, `Accounts.User`/`Token`) still have zero route regardless of mutation status, by
the same deliberate design this doc's own "Deliberately unwired" section documents below.

### Wired resources (real `base` path, real domain, both routed under `/api`)

Billing (`lib/xaas/billing/`):

| Base path | Resource module |
|---|---|
| `/approval_invoice_reconciliation_approve` | `Xaas.Billing.ApprovalInvoiceReconciliationApprove` |
| `/approval_patch_sla_credit_apply` | `Xaas.Billing.ApprovalPatchSlaCreditApply` |
| `/approval_pricing_override` | `Xaas.Billing.ApprovalPricingOverride` |
| `/approval_quota_override` | `Xaas.Billing.ApprovalQuotaOverride` |
| `/approval_sla_credit_apply` | `Xaas.Billing.ApprovalSlaCreditApply` |
| `/approval_tier_downgrade` | `Xaas.Billing.ApprovalTierDowngrade` |

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
| `/data_destruction_certificate_issue` | `Xaas.Governance.DataDestructionCertificateIssue` |

Operations (`lib/xaas/operations/`, mounted via `/api` — separate from the `/internal-api`
routes below):

| Base path | Resource module |
|---|---|
| `/approval_castle_verb_schedule` | `Xaas.Operations.ApprovalCastleVerbSchedule` |
| `/approval_k8s_fault_remediate_suggest` | `Xaas.Operations.ApprovalK8sFaultRemediateSuggest` |
| `/castle_verb_fortune5_requirements` | `Xaas.Operations.CastleVerbFortune5Requirements` |
| `/castle_verb_inventory_components` | `Xaas.Operations.CastleVerbInventoryComponents` |
| `/castle_verb_inventory_goals` | `Xaas.Operations.CastleVerbInventoryGoals` |
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

Every one of the above (except `Xaas.Billing.ApprovalPricingOverride` and
`Xaas.Governance.ApprovalBackupRetentionChange`, see below) has exactly the same real shape,
e.g.:

```elixir
json_api do
  type "..."

  routes do
    base "/..."
    get :read
    index :read
  end
end
```

So each resource is real-reachable at `GET /api/<base>` (index) and `GET /api/<base>/:id` (get),
both requiring the `Authorization: Bearer` header above.

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

Real Chicago-style coverage: `test/kanban_web/controllers/approval_pricing_override_controller_test.exs`
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
`test/kanban_web/controllers/approval_backup_retention_change_controller_test.exs` — accept
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
(`test/kanban_web/controllers/approval_{dr_failover,cmek_key_binding,dsar_erasure}_controller_test.exs`).

### Deliberately unwired (5 resources, no `json_api` block at all)

Per `lib/kanban_web/api_router.ex`'s own moduledoc, these 5 have **no** `routes do` block —
mounting `Xaas.Accounts` and `Xaas.Ledger` in the router above does not expose them:

- `Xaas.Ledger.Balance` (`lib/xaas/ledger/balance.ex`)
- `Xaas.Ledger.Account` (`lib/xaas/ledger/account.ex`)
- `Xaas.Ledger.Transfer` (`lib/xaas/ledger/transfer.ex`)
- `Xaas.Accounts.User` (`lib/xaas/accounts/user.ex`)
- `Xaas.Accounts.Token` (`lib/xaas/accounts/token.ex`) — holds cloaked `extra_data`

Reasoning stated in the router moduledoc: the ledger resources are real double-entry financial
data needing a real access-control design (whose balance can whom see?) before any open read is
safe; `User`/`Token` are real auth/PII. Both need a real business decision, not a generic
mechanical `get :read` pass.

(`Xaas.Ledger.EventLog` is not in this exclusion list in the router moduledoc's own text, but
also has no `json_api do` block per the grep above — it is unwired the same way, just not called
out by name in that comment.)

## `/internal-api` — `KanbanWeb.InternalApiRouter`

`lib/kanban_web/internal_api_router.ex` mounts `AshJsonApi.Router` for a single domain,
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

Both are registered directly on `KanbanWeb.Router` under `/internal-api`, ahead of the
`AshJsonApi.Router` forward, and both require the same `Authorization: Bearer` header.

### `GET /internal-api/capability_liveness_regressions`

`KanbanWeb.CapabilityRegressionsController`. Real response shape, taken from the real assertions
in `test/kanban_web/controllers/capability_regressions_controller_test.exs`:

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

`KanbanWeb.OcelSummaryController`. Real response shape, taken from the real assertions in
`test/kanban_web/controllers/ocel_summary_controller_test.exs`:

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

## See Also

- `lib/kanban_web/router.ex`, `lib/kanban_web/api_router.ex`,
  `lib/kanban_web/internal_api_router.ex` — the three real router files this doc documents
- `lib/kanban_web/plugs/require_internal_api_token.ex` — the real auth plug
- `lib/xaas/operations/capability_liveness_receipt.ex`,
  `lib/xaas/operations/capability_liveness_regressions.ex`,
  `lib/mix/tasks/xaas.ingest_capability_receipts.ex` — the real MAPE-K loop backing
  `/internal-api/capability_liveness_receipts` and `/internal-api/capability_liveness_regressions`
- `lib/xaas/telemetry/ocel_ash_emitter.ex` — the real OCEL v2 emitter backing `/internal-api/ocel_summary`
- `docs/ASH-MIGRATION-PLAN.md` — Phase 5 item 2, the still-open decision on a real
  customer-facing mutation surface
- `test/kanban_web/controllers/capability_regressions_controller_test.exs`,
  `test/kanban_web/controllers/ocel_summary_controller_test.exs` — real Chicago-style tests this
  doc's response shapes are grounded in
