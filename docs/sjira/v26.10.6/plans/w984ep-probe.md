# W984ep — Sweep Receipt: shared-table emptiness flake class (W650h23 root cause)

- Subject: /Users/sac/xaas @ feat/playwright-surface, HEAD 32b72c4f (no commit; working tree only)
- Lane: W984ep, MIX_BUILD_ROOT=_build-laneW984ep (removed at close: `rm -rf _build-laneW984ep` → exit 0, dir gone)
- Files touched: 6 test files. ZERO lib/ changes. No commit (per dispatch).

## Candidate matrix

Disposition key: SAFE = read scoped (org/prefix/tenant/subject/key filter), or resource not
shared (ETS), or guard-by-design. FLAKE-CLASS = unscoped emptiness/count read on a shared
Postgres table exposed to committed foreign rows in `xaas_test` (READ COMMITTED lets a
sandboxed transaction see mid-transaction commits by other sessions — W650h23's measured
class).

### SAFE (scoped reads — no change)

- test/xaas_web/json_api_surface_court_test.exs:180 — filter name
- test/xaas_web/controllers/pentest_finding_controller_test.exs:170,208 — org_id
- test/xaas_web/controllers/route_orgs_custom_domain_controller_test.exs:197,226 — org_id
- test/xaas_web/controllers/incident_controller_test.exs:147,176 — org_id
- test/xaas_web/controllers/approval_deployment_quarantine_controller_test.exs:198 — tenant for_read
- test/xaas_web/controllers/approval_patch_sla_credit_apply_controller_test.exs:264,275 — org_id
- test/xaas_web/controllers/approval_legal_hold_release_controller_test.exs:207 — tenant for_read
- test/xaas_web/controllers/approval_tier_downgrade_controller_test.exs:341 — subscription_id
- test/xaas_web/controllers/approval_dr_failover_controller_test.exs:208 — tenant for_read
- test/xaas_web/controllers/approval_backup_retention_change_controller_test.exs:325 — tenant for_read
- test/xaas_web/controllers/route_projects_backups_controller_test.exs:170,205 — org_id
- test/xaas_web/controllers/audit_export_token_controller_test.exs:144,180 — org_id
- test/xaas_web/controllers/approval_sla_credit_apply_controller_test.exs:271 — org_id
- test/xaas/ocel_deepening_test.exs:152,313 — ocel_id prefix
- test/xaas/ledger_deepening_test.exs:187,320,348,378 — account-id filters
- test/xaas/accounts_deepening_test.exs:264 — email
- test/xaas/operations/incident_test.exs:214; incident_lifecycle_deepening_test.exs:165,293,390 — org_id
- test/xaas/governance/audit_export_token_actor_policy_depth_test.exs:78 — org_id in ^[...]
- test/xaas/governance/pentest_finding_authorization_depth_test.exs:83 — SQL where org_id
- test/xaas/governance/export_token_deepening_test.exs:410 — org filter
- test/xaas/dev_seeds_idempotency_test.exs:97,131 — slug / user_id
- test/xaas/graphlaw_deepening_test.exs:234 — id filter
- test/xaas/marketplace/pack_catalog_depth_test.exs:168 — name filter
- test/xaas/governance/w984dr_environment_court_test.exs:150 — tenant count

### SAFE (structural / by-design)

- test/xaas/security_deepening_test.exs:268; test/xaas/security/finding_lifecycle_depth_test.exs:94,211,212 — Finding/Posture are `Ash.DataLayer.Ets` (not in xaas_test; foreign sessions invisible).
- test/xaas/castle_execute_court_test.exs:303,328 — unscoped `RouteCastleRun == []`, but no writer of route_castle_runs exists anywhere in lib/ (grep: zero create/for_create). Structurally unwritten table; the assertion IS the mutation guard against any future writer. Guard-by-design, kept unscoped.
- test/xaas/ultracode/test_db_leak_guard_test.exs:83 — intentional global committed-rows leak guard (the guard FOR this flake class).
- test/xaas/governance/w984dr_environment_court_test.exs:150 — tenant-scoped `Ash.count!`.

### FLAKE-CLASS → FIXED (6 files, all exit 0)

1. test/mix/tasks/xaas_self_digest_test.exs:61,85 — unscoped `WorkOrder` reads (single-row pattern match + `== []`); scoped by `subject == "ultracode-self-digest"`; added `require Ash.Query`.
2. test/xaas/witness/catalog_durability_test.exs — `receipt_rows/0` unscoped (len==2, `== rows`, verified==2, `== []`), VerificationKey `length==3` and `== []` unscoped. Fixed: `receipt_rows/1` filters by subject prefix (in-memory starts_with?); key reads filtered in memory by `key_material_hex in suite_materials` / `== unknown_material`. NOTE: this file is tagged `:eu_ai_act` (excluded by default) — runs with `--include eu_ai_act`.
3. test/xaas/ultracode/semantic_drive_test.exs:310 — unscoped `Run ... == []` (documented committed ultracode_runs leak class); scoped to the descriptor-less shape a refused drive could only produce (`is_nil(work_order_iri) and is_nil(capability_id)`).
4. test/xaas/ultracode/semantic_wave_trigger_test.exs:76,83,104,119,129,142 — oban_jobs pending counts by worker+state were unscoped; scoped by `fragment("?->>'graph_digest'", args) in fixture digests ("sha256:aaa…"/"sha256:bbb…" constants no foreign session can produce).
5. test/xaas/billing/fibo_revenue_actuation_test.exs:151,163,164 — before/after delta counts unscoped; scoped RevenueRecognition by org_id+external_ref, ActuationReceipt by resource_module (new `recognition_rows/0`, `revenue_receipts/0` helpers).
6. test/xaas/operations/autofde_planner_connector_depth_test.exs:118,192,197,207,210,216,223 — `count!/1` whole-table counts; `count!/2` filters `query == ^query` on the suite's own markers ("blocks"/"q").

## Honest limits (not silently closed)

- semantic_drive:310's scope is a shape scope, not a suite key — a mutant that persists a FULL descriptor Run would slip this filter (still killed by the suite's ledger/refused.json asserts). Partial guard, disclosed.
- wave-trigger scoping uses fixture-constant digests; a foreign session copying the constants could in principle re-trigger. Constants are suite-private strings — acceptable.
- catalog_durability_test.exs `async: true` + shared witness tables + `delete_all` setup is an intra-file race hazard (not foreign-session class); predates this lane, noted for a future lane.
- Open hazard from W650h23 stands: an unidentified writer commits liveview_librarian/toggle_pin seed rows into xaas_test (suspect e2e/seed-library.exs or a server pointed at the test DB). Until it is found, any NEW unscoped `== []` on a shared table re-arms the flake.
- In-lane compile hazard observed: `Ash.Query.filter/2` is a macro — files need `require Ash.Query` (build error: "Be sure to require Ash.Query"). Files `use`-ing Xaas.DataCase/ConnCase get it transitively; plain `use ExUnit.Case` files do not.

## Guard-tooling pattern (for future automation)

Scan test/** for `Ash.read!|Repo.all|Ash.count!|length()` results compared with `== []`,
`Enum.empty?`, `== 0`, or used as before/after delta pairs on unfiltered reads. Classify:
ETS-backed resource or structurally unwritten table (no lib/ writer) → SAFE;
org/prefix/tenant/subject/key-filtered → SAFE; otherwise FLAKE-CLASS → require a suite-owned
scope. Delta-count pairs must filter both sides identically. Also: `require Ash.Query`
presence check for plain ExUnit files introducing filters.

## Verification (real runs, pinned asdf toolchain, MIX_BUILD_ROOT=_build-laneW984ep, fresh lane build)

```
mix test test/mix/tasks/xaas_self_digest_test.exs                          → Result: 3 passed, EXIT=0
mix test test/xaas/witness/catalog_durability_test.exs --include eu_ai_act → Result: 4 passed, EXIT=0
mix test test/xaas/billing/fibo_revenue_actuation_test.exs                 → Result: 5 passed, EXIT=0
mix test test/xaas/operations/autofde_planner_connector_depth_test.exs     → Result: 5 passed, EXIT=0
mix test test/xaas/ultracode/semantic_drive_test.exs                       → Result: 16 passed, 5 skipped, EXIT=0 (skips = pre-existing module GGEN_IGNITER_DIR condition)
mix test test/xaas/ultracode/semantic_wave_trigger_test.exs                → Result: 8 passed, EXIT=0
mock gate grep (patch(/Mock/mock) over the 6 touched files                 → zero matches ([])
```

## Standing: ALIVE (all edited suites exit 0, mock gate clean, no commit per dispatch)
