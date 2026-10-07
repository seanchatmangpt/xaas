# W905 — DESIGN-Class Gap Implementation Specs (18 rows from W891 triage)

- Lane W905, xaas v26.10.6, repo `/Users/sac/xaas` @ `feat/playwright-surface` HEAD `a0723bf6`.
- **Method**: every spec derived from its disclosing receipt's typed-gap section (read in
  full, not from the register line): w722, w729, w731, w750, w765, w770, w793, w796, w799,
  w819, w824, w849. No surface invented beyond the receipt's named gap; court patterns cite
  landed repair-wave receipts (W740/W772/W809/W818) or the receipt's own landed court.
- **Standing**: PARTIAL_ALIVE — doc-only backlog for the DESIGN wave; no code, no build
  root, no commit. Register rows unchanged until waves land.
- **Estimates**: S ≤1 lane/file+test, M = multi-file or one migration, L = cross-tree or
  protocol surface. Sequencing: 16→17 block on 15 (CHEAP wave); 31 blocks on 30; 20/21
  share the W770 file family.

## Governance

### SPEC-04 (W722-GAP-2) — Authenticated org identity (org auth plug), M
- Surface: new `XaasWeb.Plugs.AuthenticateOrg` (authenticates caller → binds org), wired in
  `lib/xaas_web/router.ex` ahead of `XaasWeb.Plugs.ResolveOrgActor` on `/internal-api`;
  `ResolveOrgActor` demoted to derive-from-authenticated-identity (its moduledoc already
  discloses the caller-asserted `X-Org-Id` limitation).
- Migration: none at resource layer; auth credential storage decision (org API keys or token
  claim) may need one table — spec leaves the credential mechanism to the implementer's
  existing `INTERNAL_API_TOKEN`-adjacent pattern, fail-closed like `RequireInternalApiToken`.
- Court: mirror W722's own lens-(d) ConnCase block
  (`test/xaas/governance/multitenant_approval_deepening_test.exs`) flipped to assert refusal
  of forged `X-Org-Id` under a authenticated-different org; plus a 401/403 matrix mirroring
  W745's (d) auth-floor court.
- Falsifier: a request with authenticated org A + header org B must be refused, not honored.

### SPEC-16 (W765-GAP-B) — `:use`/`:consume` action on AuditExportToken, M
- Surface: `action :use` in `lib/xaas/governance/audit_export_token.ex` (accepts raw token,
  hashes, matches `token_hash`); new `used_at`/`use_count` attributes.
- Migration: one migration adding `used_at :utc_datetime_usec` (nullable) to
  `audit_export_tokens`.
- Court: mirror the landed `AuditExportTokenNotAlreadyRevoked` guard idiom (same file, W740
  class): a `NotAlreadyUsed` validation refusing second use; test mirrors
  `test/xaas/governance/export_token_deepening_test.exs` determinism block.
- Sequencing: blocked on SPEC-15 (GAP-A, `expires_at` in `:issue` accept list — CHEAP wave).

### SPEC-17 (W765-GAP-C) — Refuse reuse-after-expiry, S (after SPEC-16)
- Surface: `ExpiredTokenRefused` validation on the new `:use` action in
  `lib/xaas/governance/audit_export_token.ex`; expiry today is calculation-only
  (`active?` flips, no action consults it).
- Migration: none (consumes `expires_at` from SPEC-15).
- Court: W740-mirror change-validation + mutation-kill; test extends
  `export_token_deepening_test.exs` with expired-then-use refusal (typed
  `Ash.Error.Invalid`, field `:expires_at`).
- Sequencing: blocked on SPEC-16 (no `:use` action exists to guard).

### SPEC-18 (W765-GAP-D) — Runtime consumer gate on active freeze window, M
- Surface: new `Xaas.Governance.Checks.FreezeWindowActive` check + wiring onto the deploy-
  class actions the receipts name as ungated today (export/deploy-adjacent actions in
  `lib/xaas/governance/`); the only current enforcement is
  `ApprovalFreezeOverrideFreezeWindowExists` (override path only).
- Migration: none (reads existing `starts_at`/`ends_at`).
- Court: mirror W770's RouteOrgsCustomDomain org-matched refusal pattern; test asserts an
  action inside an active window refuses with a typed policy error naming the window, and
  `allow_emergency_override: true` + override row admits (the two existing behaviors stay).

## Billing

### SPEC-07 (W729-GAP-3) — `multitenancy do` across the billing tree, M
- Surface: `multitenancy :attribute :org_id` (global? no — attribute strategy) on all 8
  `Xaas.Billing` resources (`subscription.ex`, `approval_pricing_override.ex`,
  `approval_sla_credit_apply.ex`, +5 siblings under `lib/xaas/billing/`);
  `Subscription.subscription.ex` itself names this as disclosed follow-up.
- Migration: likely none (org_id column exists as loose string); verify NOT NULL + index on
  all 8 tables, add backfill migration where org_id can be nil.
- Court: mirror W722's lens (a) tenant-isolation block (typed `NotFound` under wrong tenant,
  cross-org `:approve` → `ActorOrgMatches` policy refusal) applied to billing resources.
- Risk: `SlaCreditActorOrgMatches` policy checks may become redundant — keep, don't delete,
  per Chesterton fence; note in the lane receipt.

### SPEC-08 (W729-GAP-4) — atomic_update retrofit across billing tree, L
- Surface: convert the money-moving mutations (`:sync_from_stripe` charge,
  `ApprovalSlaCreditApply :approve` credit, `:change_tier`) from `after_action/2`
  same-transaction Ledger writes to `atomic_update`/`atomic` in
  `lib/xaas/billing/changes/*`.
- Migration: none; this is execution-semantics, but requires Ash atomic-callback
  compatibility for each change module (some `after_action` bodies may be non-atomicizable —
  those stay and are disclosed, not forced).
- Court: mirror W729's own lens-(d) atomic-quantity block plus a concurrency test
  (two simultaneous `:approve` on a stale record → exactly one credit; extends the
  W746-class `filter(expr(is_nil(approved_by)))` DB guard already landed on Transfer).
- Sequencing: after SPEC-06 (W729 approve-idempotency, CHEAP wave) lands the DB-level guard.

## Ledger

### SPEC-27 (W799-GAP-1) — Dedicated ledger reversal action, M
- Surface: `action :reverse` on `Xaas.Ledger.Transfer` (`lib/xaas/ledger/transfer.ex`)
  minting a compensating transfer with from/to swapped in one transaction; grep evidence in
  receipt: zero `:refund|:reverse|:undo` exist today.
- Migration: add `reverses_transfer_id :uuid` (nullable, unique) to `transfers` so
  double-reversal is a constraint, not an accident of sufficiency.
- Court: mirror W746's DB-level `filter` guard class (already landed on this resource):
  second `:reverse` on the same transfer refused typed, independent of balances; extends
  `test/xaas/ledger/reversal_deepening_test.exs` block (b), which currently pins the
  sufficiency-accident refusal.
- Note: compensating-`transfer` round trip (receipt block a/c) stays as the mechanism;
  `:reverse` wraps it lawfully.

## Platform

### SPEC-09 (W731-GAP-1) — `:capability_class` enum on Graphlaw Capability, S
- Surface: new attribute `capability_class :atom` (constraints one_of `[:observe, :select,
  :construct, :do]`, default `:observe`) on `Xaas.Graphlaw.Capability` (`lib/xaas/graphlaw/
  capability.ex`); the brief's assumed enum does not exist — this spec creates it.
- Migration: one migration adding the nullable column + backfill default.
- Court: mirror W731's own create/accept-list assertions (13-test block): accept list grows,
  out-of-enum value → typed `Ash.Error.Invalid` naming the field; extend
  `test/xaas/graphlaw_deepening_test.exs` (which currently pins the attribute's absence).

### SPEC-10 (W731-GAP-2) — EngineLimit enforcement gate, L
- Surface: new `Xaas.Graphlaw.LimitGate` (`lib/xaas/graphlaw/limit_gate.ex`) consuming
  `Catalog.limits_by_scope/1`; wired at the two named consumer seams: `Xaas.Bridges.Graphlaw`
  (WASM purchase-policy bridge) and `Xaas.Bridges.Registry` — neither reads EngineLimit rows
  today.
- Migration: none (registry rows exist; the gap is the absent consumer).
- Court: mirror W731's `limits_by_scope/1` real-row block + a new gate test: limit value
  exceeded → typed refusal naming `refusal_name` (the column already exists for exactly
  this); a 1,000,000 `max_json_depth` against a real depth-65 payload must refuse, not
  persist happily.
- Design note: enforcement point choice (pre-invocation check vs. WASM boundary) is the
  implementer's; the falsifier is consumer-gating observable in test, per the receipt.

### SPEC-20 (W770-GAP-2) — RouteProjectsBackups `:update`/`:destroy` + retention sweep, M
- Surface: add `:update` (status transition `pending → archived/pruned`) and `:destroy` to
  `lib/xaas/platform/route_projects_backups.ex`; today an update attempt raises the real
  typed surface `ArgumentError: No such update action` (pinned in
  `platform_route_deepening_test.exs`).
- Migration: none (status column exists).
- Court: mirror W770's block 1 (`Xaas.Checks.SystemActor` gating, as the sibling
  RouteFeatureFlags/RouteSecrets resources already enforce) + a retention-sweep Oban-ish or
  manual `mix xaas.platform.prune_backups` task asserted on real rows.
- Sequencing: same file family as SPEC-21 — one lane, disjoint test blocks.

### SPEC-21 (W770-GAP-3) — RouteProjects create/approve surface, M
- Surface: add `:create` + `:approve` (maker-checker pair) to
  `lib/xaas/platform/route_projects.ex`; today only `:read` exists, so `approved_by`/
  `requested_by` metadata can never be produced (pinned via `ArgumentError` on create).
- Migration: none (columns exist, unwritable).
- Court: mirror W770's RouteOrgsCustomDomain block: `ActorOrgMatches` cross-org refusal,
  maker-checker distinct-actor validation reusing the W740-class
  `*RequiresApprover`/`ApprovalNotAlreadyApproved` idiom — and, unlike the five vacuous
  pass-throughs (row 19, CHEAP wave), wire REAL validation bodies here.
- Sequencing: do after row 19 (vacuous-approval wire-or-retire) so the new actions consume
  the real validation modules, not new parallel ones.

### SPEC-30 (W819/W802-GAP-1) — Mount GraphQL over HTTP, M
- Surface: `forward "/graphql"` via `Absinthe.Plug` in `lib/xaas_web/router.ex` behind the
  existing `:require_internal_api_token` floor (`XaasWeb.Plugs.RequireInternalApiToken`) —
  CLAUDE.md API-auth floor: no unauthenticated sibling route; `Xaas.GraphqlSchema` already
  compiles.
- Migration: none; config only if schema pooling needs it.
- Court: mirror W750's block (a) real-HTTP round trip (ConnCase GET/POST through the real
  router, 401 without token) — a query per wired domain returns real rows; doc update to
  `docs/claude/diataxis/reference/ash-configuration.md` "GraphQL surface status" subsection
  (flip `UNSUPPORTED(graphql-http-surface)` with the new receipt cited).
- Sequencing: blocks SPEC-31.

### SPEC-31 (W819/W802-GAP-2) — Wire remaining 16 of 19 domains into GraphqlSchema, M (after SPEC-30)
- Surface: extend `lib/xaas/graphql_schema.ex` `domains:` list beyond
  `[Xaas.Operations, Xaas.Library, Xaas.Marketplace]`; per-domain add one at a time (compile
  gate per domain; some of the 19 may fail AshGraphql extension — those are disclosed
  UNSUPPORTED(graphql-domain-N), not forced).
- Migration: none.
- Court: extend SPEC-30's HTTP court with one query per newly wired domain; update the
  diataxis "3 of 19" count only from real wired-domain output, same overclaim rule W819
  enforced in reverse.

### SPEC-34 (W849-backlog-2) — CI/regen drift leg for generated surfaces, L
- Surface: new CI workflow step (or `mix xaas.generated.regen_check` task invoked in CI)
  running each surface's named regen command (`ggen sync` packs, `mix ggen_igniter.sync
  --pack-dir ...`, `mix ash_typescript.codegen`) and byte-comparing against the tree —
  upgrades registry guards 1-6 from sha256-pin to regen-based DRIFT-CHECKED.
- Migration: none; depends on the sha256-map extension (row 33, CHEAP wave) landing first so
  all 12 census surfaces are pinned before regen is trusted.
- Court: mirror W837's `ts_codegen_drift_court_test.exs` (the only existing real
  regen-and-byte-compare court) generalized; falsifier per W849: injected hand-edit of any
  generated file must fail the leg.
- Note: hostile-neighbor risk (concurrent lanes editing generated files) — run as separate
  CI job, not in-lane test, per W799's disclosed 13-min compile-block lesson.

## Ultracode

### SPEC-32 (W824-GAP-1) — QuiescentStop envelope on the MCP wire, L
- Surface: per w824's own tail, one of two named options: (a) dedicated fabric halt verb in
  `Xaas.Ultracode.Lease`/dispatch (`lib/xaas_web/` MCP dispatch path) routing to
  `QuiescentStop.execute/2`, or (b) a QuiescentStop projection of the kernel envelope
  mapping `{status, replay, intent_id, receipt_id}` → `{stopped_at, target: :quiescent,
  authority}` / `{:error, :REFUSED_STOP_*}`.
- Migration: none; all rows (Run/Epoch/ActuationIntent/ActuationReceipt) exist.
- Court: extend W824's own `test/xaas_web/quiescent_fabric_tie_test.exs` block (a): after
  the halt through the NEW surface, the wire body carries the module's typed envelope, not
  the raw kernel one; keep block (b) `"replayed"` idempotency contract green.
- Recommendation: option (b) first (projection, no new authority surface); option (a) is a
  new verb = new authority grant, needs its own lease gating per BRCE doctrine.

## Operations

### SPEC-14 (W750-G2) — Regression-detectable liveness history, M
- Surface: add `previous_status :string` (nullable) to
  `lib/xaas/operations/capability_liveness_receipt.ex` (or an append-only observation-log
  resource `CapabilityLivenessObservation`); `:ingest` upsert writes the prior status before
  overwrite; `detect/1` reads it.
- Migration: one migration (column or new table); the receipt names both shapes as
  acceptable, column is the smaller blast radius.
- Court: W740-mirror change on `:ingest` + extend `capability_liveness_deepening_test.exs`
  block (c): a real ALIVE→non-ALIVE re-ingest must now fire `detect/1` (currently pinned
  invisible); the existing test pinning the blindness flips as the visible diff.
- Sequencing: composes with row 13 (W750-G1 `ALIVE_WITHOUT_EXECUTION` validation, CHEAP
  wave) — same file, land G1 first.

### SPEC-24 (W793-GAP-5) — Incident↔castle cross-reference, M
- Surface: new `incident_id :uuid` attribute + relationship on the four route-castle ledgers
  (`RouteCastleDeploy`/`RouteCastleRun`/`RouteCastleSchedule`/`RouteCastleSunset` under
  `lib/xaas/operations/`) or a relationship on `Xaas.Operations.Incident`; note the ledgers
  have `write_actions == []` (generated-projection role) — so the link likely lands on
  Incident (castle_reference) unless the projection generator is extended.
- Migration: one migration (attribute + FK or join).
- Court: mirror W793's introspection block (`Ash.Resource.Info.attributes/relationships`)
  asserting the link exists and flips the `NO_CROSS_REFERENCE` pin; the four-gap drift flag
  from W891 (row 23) must be re-verified against HEAD before this lane opens.
- Sequencing: after row 23's split-and-reverify (CHEAP wave) to avoid repairing a stale row.

### SPEC-26 (W796-G3) — Fulfilled hold mints a real Checkout, M
- Surface: make `Xaas.Library.Changes.FulfillNextHold` → `HoldRequest :fulfill` also mint a
  real `Checkout` row (`:borrow` path) for the hold reader in one transaction
  (`lib/xaas/library/changes/fulfill_next_hold.ex`); today the hold row is the only durable
  fulfillment record.
- Migration: none (Checkout exists); decision needed: the returned copy is already
  re-decremented by `Book :borrow_copy` — the mint must consume that hand-off, not
  double-decrement (receipt block b documents the exact inventory flow).
- Court: mirror W809's DB-reading guard idiom + extend `checkout_policy_deepening_test.exs`
  block (b): 1-copy book borrow→return now leaves a real Checkout row for the hold reader
  with `returned_at == nil`; the current pin (no Checkout minted) flips as the visible diff.
- Sequencing: after rows 25/G1-G2 (borrow cap, return guard — CHEAP wave) touch the same
  resource family; disjoint test files, land guards first.

## Estimate summary

- S: SPEC-09, SPEC-17 (2)
- M: SPEC-04, SPEC-07, SPEC-16, SPEC-18, SPEC-20, SPEC-21, SPEC-24, SPEC-26, SPEC-27,
  SPEC-30, SPEC-31, SPEC-14 (12)
- L: SPEC-08, SPEC-10, SPEC-32, SPEC-34 (4)
- Fan-out seams: SPEC-20/21 share the W770 family; SPEC-16/17 sequential same-file;
  SPEC-14 composes with CHEAP row 13; SPEC-30→31 sequential. All other lanes disjoint.

## Design wave tracking (W982l reconciliation, 2026-10-07)

W982l pass: every row re-verified from disk evidence (receipt files present, commit SHAs
real via `git log`, implementation surfaces grepped on tree). Corrections vs the W971a
table are marked CORRECTED. Receipt-or-commit references verified this pass.

| spec id | wave lane | status | receipt-or-commit reference (verified W982l) |
|---|---|---|---|
| SPEC-04 | W969b | LANDED-COMMITTED | `5a853130` (receipt `w969b-design-wave2.md` on disk; `lib/xaas_web/plugs/authenticate_org.ex` on tree) |
| SPEC-18 | W969b | LANDED-COMMITTED | `5a853130` (receipt `w969b-design-wave2.md`; check + wiring + court) |
| SPEC-14 | W968c | LANDED-COMMITTED | `fd471722` (receipt `w968c-design-wave1.md` NOW ON DISK — W971a's "receipt file absent" note CORRECTED) |
| SPEC-27 | W968c | LANDED-COMMITTED | `352cc34c` (receipt `w968c-design-wave1.md`; `lib/xaas/ledger/changes/reverse_transfer.ex` on tree) |
| SPEC-21 | W969c | LANDED-COMMITTED | `b2758300` + `fc14f10b` (receipt `w969c-design-wave3.md`; `route_projects_create_court_test.exs` in `b2758300` stat) |
| SPEC-09 | W912 (pre-wave) | LANDED-COMMITTED | `aa2b4022` (real, `git log` witnessed) |
| SPEC-16 | w935 (pre-wave) | LANDED-COMMITTED | `fab56ae1` + `c3df69a8` (receipt `w935-spec16-impl.md` on disk) |
| SPEC-17 | w935 (pre-wave) | LANDED-COMMITTED | `fab56ae1` (closed in-lane per `w935-spec16-impl.md` §SPEC-17 disposition; `c3df69a8` adjacent hardening) |
| SPEC-20 | W970b | LANDED-COMMITTED | `b2758300` (receipt `w970b-open-sweep.md` row 1; shape deviation disclosed: `destroy :purge_expired` + retain_until validation, not generic `:update`/`:destroy`) |
| SPEC-24 | W970b | LANDED-COMMITTED | `b2758300` (receipt `w970b-open-sweep.md` row 2; Incident-side `castle_run_id` + migration, per spec's predicted landing shape) |
| SPEC-26 | W970b | LANDED-COMMITTED | `b2758300` (receipt `w970b-open-sweep.md` row 3; hold `:fulfill` mints real Checkout in-transaction) |
| SPEC-07 | W970a + W975b | REPAIRED | Full SPEC-07 COMMITTED: W970a's 4 resources at `39c405fc` + court/fixture at `bf9f5cb9` (W982k integration, `w982k-spec07-integration.md`); W975b's second half (subscription, approval_sla_credit_apply, approval_patch_sla_credit_apply, revenue_recognition + court tests 4/5) landed at `ddb19522` (w982b integration, restoring content swept by `691e0a93`). Convention skew RESOLVED: all 8 billing resources use `global?(true)` (verified by grep at completion, w983o). Gates re-witnessed at HEAD by W983o: fresh-root `mix compile --force --warnings-as-errors` EXIT=0; billing dir 40 passed; court 5/5; `multitenancy_deepening_test.exs` 9 passed. `w975b-retroactive-mint.md` remains REFUSED(stale-evidence) (superseded by landed content, not needed). |
| SPEC-08 | — | STILL-PENDING | no lane, no receipt, no atomic_update diff in `lib/xaas/billing/changes/` |
| SPEC-10 | W976 (design-wave 5) | LANDED-UNCOMMITTED | receipt `w976-design-wave5.md` on disk; `lib/xaas/graphlaw/limit_gate.ex` + both consumer wires on tree (uncommitted; W982k integration) |
| SPEC-30 | W975b (design-wave 4) | LANDED-UNCOMMITTED | receipt `w975b-design-wave4.md` §SPEC-30; `lib/xaas_web/router.ex:302-313` Absinthe.Plug forward + `mix.exs:148` `{:absinthe_plug, "~> 1.5"}` + `test/xaas_web/graphql_http_surface_test.exs` (5 tests, mutation-killed ×1) all on tree uncommitted |
| SPEC-31 | W973c (design-wave 8) | LANDED-UNCOMMITTED | receipt `w973c-design-wave8.md`; `lib/xaas/graphql_schema.ex` 19 domains verified by grep; court `test/xaas/graphql_domain_wiring_court_test.exs` on tree |
| SPEC-32 | — | STILL-PENDING | banned surface per `w969c-design-wave3.md`; no lane, no receipt |
| SPEC-34 | — | STILL-PENDING | no CI leg, no regen-check task, no receipt |

W982g is running — its spec attribution is left IN-FLIGHT (no W982g receipt on disk at
writing time; do not pre-attribute). Historical W971a tracking table preserved in git
history and in `w971a` receipts; superseded rows (e.g. SPEC-20 "IN-FLIGHT unattributed",
SPEC-07 collision note, SPEC-31 "5 of 16") are resolved by the verified rows above.

In-flight lanes W969e/W969f/W970a: W970a's receipt now exists on disk
(`w970a-design-wave6.md`) and claims SPEC-07's half with `global?(true)` blocks — but the
current tree shows a DIFFERENT convention (required tenant + `allow_global`, per its own
file comments naming lane W975b as the converged convention). Reconcile convention skew
at integration.

