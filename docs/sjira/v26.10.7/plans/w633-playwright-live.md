# W633 — ASH_SURFACE Playwright headless verification vs live ~/xaas (fleet-seal checklist item 2)

- Date: 2026-10-07
- Lanes: read-only `~/ash_surface`; `~/xaas` boot-only (one 2-line `config/dev.exs`
  override applied and since-reverted, byte-identical restore verified by empty
  `git diff` — w890 recipe).
- Baseline: 371/371 (w901), re-certified 371/371 at current tree by w611.

## 1. Dev-instance boot

- Shared `xaas_dev` migrate attempted under release authority
  (`MIX_ENV=dev mix ecto.migrate`): **BLOCKED(db), typed** —
  `Postgrex.Error 23505 unique_violation` creating
  `ultracode_epochs_orgless_run_cycle_index` (migration `20261007010000`):
  109 duplicate `(run_id, cycle)` rows exist in `ultracode_epochs`
  (counted via real SQL, not inferred). Migration ordering defect: the
  dedup migration `20261007120000` is sequenced AFTER the index migration
  that fails without it. Same class as w890's handoff; not fixed by this lane.
- Fallback per checklist / w890 recipe: private DB `xaas_dev_w633` =
  schema-only `pg_dump` of xaas_dev + `schema_migrations` rows copied
  (75 versions). First fresh-migrate attempt on the clone replayed
  migration 1 and died on `42710 duplicate_object` (`money_with_currency`
  already exists) — resolved by copying `schema_migrations` data. After the
  copy, `MIX_ENV=dev DEV_DB_NAME=xaas_dev_w633 mix ecto.migrate` ran all 9
  pending migrations (`20261007010000`..`20261007250000`) cleanly —
  schema-only clone has no duplicate rows, so the index creates fine.
- Config override: `config/dev.exs` lines 26/43 changed to
  `database: System.get_env("DEV_DB_NAME", "xaas_dev")` (both repos), env
  `DEV_DB_NAME=xaas_dev_w633`; backed up to `/tmp/w633_dev_exs.bak`,
  restored after the run, `git diff` empty.
- Boot: `MIX_ENV=dev DEV_DB_NAME=xaas_dev_w633 INTERNAL_API_TOKEN=<openssl
  rand -hex 32> PORT=4033 mix phx.server` (token at `/tmp/w633_token`).
  Server answered HTTP 200 on `/` after ~105s (dev compile under fleet
  load). Full boot log: `/tmp/w633_server.log`.
- Load doctrine: load average 102.35 at start, 95.98 at suite time — above
  the 10.0 gate; waited and re-checked, contention is standing fleet-wide.
  Results below are recorded under that qualification. No rerun changed
  any outcome (single runs, all green).

## 2. Suites run

### a. ash_surface `npm test` (371-test Chromium suite, hermetic)

```
ℹ tests 371
ℹ pass 371
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ duration_ms 9532.967166
```

Real headless Chromium (playwright runtime already in `node_modules` from
w611's documented CI recipe; 0 skipped = real launches, no hermetic skip).
**Exact 371/371 baseline match. Zero failures to classify — no
removal-regression, no flake, no env failure.**

Note: this suite is hermetic by construction — its Chromium cases target a
`data:` URL fixture (test/js/playwright_accessibility.test.mjs), not the
live instance. The live-instance leg is covered by (b).

### b. Live-instance Chromium court: ~/xaas e2e `ash-surface-client.spec.cjs`

`PW_PORT=4033 npx playwright test e2e/ash-surface-client.spec.cjs` against
the booted live dev server (`reuseExistingServer` latched onto it;
readiness probed via real HTTP). Real Chromium, real served projection:

```
  ✓ serves /surface_contract.json with 200
  ✓ serves /xaas_ash_surface_client.mjs with 200
  ✓ serves /ash_surface_runtime.mjs with 200
  ✓ surface_contract.json is machine-readable with generatorIdentity and manifestDigest
  ✓ generated runtime .mjs compiles as valid JavaScript in the browser
  ✓ generated client .mjs compiles as valid JavaScript in the browser
  6 passed (55.2s)
```

(One known failure-tolerant global-setup note: library seed did not report
W823_SEED_OK — documented in w890 as ETIMEDOUT-on-boot-probe class,
non-fatal by design, unrelated to the served ash_surface surface.)

## 3. Classification

No failures anywhere → nothing to classify. Zero contract regressions
post-GraphQL excision on both surfaces:
- ash_surface projected suite: 371/371 (exact baseline)
- live served ash_surface projection court: 6/6

## 4. Cleanup (witnessed)

- Server shut down cleanly: SIGINT to PID 92180, port 4033 freed, BEAM down.
- `config/dev.exs` restored (empty git diff).
- Private DB `xaas_dev_w633` dropped.
- Nothing committed (lane contract).

## Standing

- **ALIVE** — zero-regression certificate post-GraphQL excision: ash_surface
  371/371 real Chromium (baseline-exact) + live-instance served-projection
  Chromium court 6/6 on a freshly migrated private dev DB.
- **BLOCKED(db), foreign-lane, pre-existing**: shared `xaas_dev` cannot
  migrate until the dedup/index ordering (`20261007010000` vs
  `20261007120000`) and the 109 duplicate epochs are resolved. Every
  `MIX_ENV=dev mix ecto.migrate` on xaas_dev will fail at 010000 until then.
- Typed gap: w611's byte-freshness regen verdict for 26.10.7 (projection
  byte-stale, org_id zod) remains open — behavioral compatibility certified
  here is not byte freshness.
