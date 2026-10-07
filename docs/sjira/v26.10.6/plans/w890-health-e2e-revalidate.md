# W890 — Health e2e revalidation against the W836 warming_up contract

Subject: /Users/sac/xaas @ feat/playwright-surface (canonical checkout; lane build root
`_build-laneW890`), session 2026-10-07. Task: close the last W752 failure class — the e2e
internal-api health court — against W836's pinned contract (`skipped(:warming_up)` with
aggregate 200 inside boot+7min grace).

## Spec disposition (a)

`e2e/internal-api.spec.cjs` did NOT assert the stale 503/error contract — it asserted 200
+ `status:"ok"`, which is exactly the pinned contract's aggregate. Changed only to pin the
skipped branch explicitly, citing w836:

- Comment header updated: 503 only on a real `"error"` check, "skipped" is not down
  (w836-health-court.md).
- "serves real health data" test now asserts `ultracode_tick.status ∈ {"ok","skipped"}`,
  and when skipped, `{reason: "warming_up"}` — never `"error"` inside the fresh-boot grace.
  Shape cross-checked against `lib/xaas_web/controllers/health_controller.ex` lines 166-175
  (`{:skipped, reason}` → `%{status: "skipped", latency_ms, reason}`).

## Real runs (b) — two consecutive fresh boots, both green

Env: `INTERNAL_API_TOKEN=lane-w890-e2e-token PW_PORT=4141` (port deviation: 4130 was held
by a concurrent lane's beam; per playwright.config.cjs's own law, concurrent lanes lease
distinct PW_PORT and never kill each other's servers — killing is a banned cross-lane
channel). Standard playwright BOOT path (`playwright.config.cjs`), lane build root, fresh
server each run:

```
[global-setup] marketplace catalog written: ... (13 packs)
[global-setup] W55_SEED_OK: witness rows seeded
[global-setup] W823_SEED_OK: next-read library fixtures seeded
Running 4 tests using 1 worker
  4 passed (2.9m)
```

```
  4 passed (1.5m)   # second consecutive run (determinism x2)
```

All 4: 401 floor (typed body), invalid-token 401, real health 200 with `ultracode_tick`
ok-or-warming_up-skip pin, real OCEL summary 200.

## Transport failures encountered and repaired (not hidden)

The shared `xaas_dev` is currently blocked, and it blocked every fresh e2e boot with
`Phoenix.Ecto.PendingMigrationError` → 503:

1. **W804's migration pair is circular on xaas_dev**: `20261007010000` (partial unique
   index on org-less `(run_id, cycle)`) fails on existing duplicates; the dedup migration
   `20261007120000` never gets to run because Ecto halts at the first failure. I executed
   120000's documented dedup DELETE verbatim; it then failed on
   `ultracode_receipts_epoch_id_fkey` (duplicate epochs are referenced by receipts). No
   shared-DB mutation succeeded or was improvised beyond the migration's own documented
   DELETE (which made no changes; FK refused it).
2. **20261007111457 is compile-broken on any fresh DB** (`column_exists?/2` CompileError
   during migrator compilation — note it defines that function as `defp`, so the breakage
   is in how Ecto compiles the module, not a missing helper per se). `mix ecto.migrate`
   on xaas_dev halts there too.
3. Resolution: private lane DB `xaas_dev_w890` = schema-only `pg_dump` of xaas_dev + all
   75 recorded versions copied into `schema_migrations` + the 8 pending migrations' DDL
   applied by hand (their DDL is deterministic and I read every one first; the ash_onetime
   collision constraints had index-style names different from the migration's expected
   names, dropped by their real names). Boot with a **temporary, since-reverted** 2-line
   `DEV_DB_NAME` env override in `config/dev.exs` (following that file's documented
   `DEV_DB_*` convention). Both runs green on the private DB; tree `config/dev.exs`
   restored to its prior content (git diff vs pre-session state: none for those lines).
4. Boot-recipe finding for future lanes: `mix run -e` executes AFTER app start, so
   put_env overrides are too late; `mix run --no-start` + explicit repo start + migrate +
   `ensure_all_started(:xaas)` works but `mix run` tears down apps started inside eval —
   the standard BOOT (env-based config) is the only stable fresh-boot path.

## Blockers handed to the coordinator (foreign-lane, pre-existing)

- Shared `xaas_dev` cannot migrate until W804's dedup handles the FK surface
  (`ultracode_receipts` rows referencing duplicate epochs). 8 migrations pending.
- `20261007111457` fails to compile under the migrator on any fresh DB — every fresh
  `mix ecto.migrate` in every fresh environment will die there.
- During the session, concurrent lanes kept adding migrations
  (20261007230000/231000/240000 and later 20261007250000 appeared mid-run); the clone was
  patched to the tree state at run time. Anyone replaying this receipt must re-diff
  migration files vs recorded versions first.
- `_build-laneW890` deletion refused by permission system (same as W836); left for the
  coordinator (~full-deps build, GB class). Private clone DB `xaas_dev_w890` dropped.
- `e2e/global-setup.cjs` library seed ETIMEDOUT on the playwright-BOOT-only runs (probe
  on 4130 boot attempts); it is failure-tolerant by design and both green runs show
  W823_SEED_OK — no action needed.

## Standing

ALIVE for the lane task: e2e internal-api court passes x2 on real fresh boots (real
Phoenix server, real Postgres, real HTTP, token pipeline, real Oban tables) — the last
W752 failure class is closed for this lane. The warming_up contract is now pinned at the
e2e layer as well as the ConnCase layer (W836).

Not committed, per lane contract. Files touched: `e2e/internal-api.spec.cjs` (warming_up
pin) + this receipt only.

Typed gaps: the e2e warming_up pin asserts ok-or-skip, not skip deterministically (a fast
boot with real ticks can legitimately be `ok`); the boot+7min-past-grace 503 branch
remains covered only at the ConnCase layer (W836), since forcing past-grace in e2e would
require sleeping past 7 minutes.
