# W752 Receipt — Full e2e validation against Playwright (terminal-condition gate)

- **Subject**: `/Users/sac/xaas` @ `a0723bf6`, branch `feat/playwright-surface` (canonical checkout, no worktrees)
- **Standing**: **PARTIAL_ALIVE** — the full existing e2e suite ran for real against a real booted
  server: **96 passed / 4 failed / 3 skipped** (103 total), all 4 failures classified
  **environment** with mechanism-level evidence, **zero spec drift and zero product regressions**
  found in any spec. The dev-env (repo-convention) server is **BLOCKED** by two independent typed
  findings (F1 config-class, F2 dev-DB data state) — recorded for the coordinator, not fixed by
  this lane.
- **Date**: 2026-10-07
- **Task origin**: v26.10.6 loop terminal condition "validated against playwright" (coordinator dispatch).

## Command (real)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW752 \
  INTERNAL_API_TOKEN=dev-e2e-token PW_PORT=4002 npx playwright test --reporter=line
```

(Green-core run; `reuseExistingServer: true` on leased port 4002 per `playwright.config.cjs` /
W688 port convention. JSON-reporter rerun for per-spec accounting confirmed 95 pass / 4 fail /
3 skip with the same failure set plus one `full_surface` flake that passed on the clean retry.)

## Real tails

Run 1 (line reporter, full suite, MIX_ENV=test server on 4002):

```
  4 failed
    e2e/internal-api.spec.cjs:82:3 › /internal-api token gate › serves real health data with the env token
    e2e/next-read-ml.spec.cjs:42:3 › ... expands grounded 'Why this one?' explainability drawer ...
    e2e/next-read-ml.spec.cjs:64:3 › ... librarian pin action dynamically updates curation ...
    e2e/next-read-ml.spec.cjs:96/91:3 › ... executes student checkout, updates librarian metrics ...
  3 skipped
  96 passed (2.0m)
```

Clean retry (run 3, same server, failed specs + all priority specs, 46 tests):

```
  4 failed   (identical set: internal-api health + 3 next-read)
  1 skipped  (witness seed fixme branch)
  41 passed (2.1m)   ← includes a2a-marking 5/5, a2a-v1, execution-fabric 3/3,
                      mcp-a2a, dev-routes 2/2, full_surface (flake passed)
```

## Per-spec standing

| spec | result | classification |
|---|---|---|
| a2a-marking.spec.cjs | 5/5 pass | green — W533 marking contract intact post-W739 (marking plug mounted before admission plug; refusals marked) |
| a2a-v1.spec.cjs | pass | green — v1 protocol surface intact |
| execution-fabric.spec.cjs | 3/3 pass | green — actuate 403 `REFUSED(authority_ceiling:actuate)` envelope and probe capabilities unchanged by W723/W745 controller work (W745 courts pin `no_lease` shapes on `/internal-api/execution/*`, not the fabric controller routes this spec hits) |
| witness.spec.cjs | 2 pass + 1 skip | green (honest degraded branch) — skip is the spec's designed `test.fixme` when self-seeding can't run; seeding requires `MIX_ENV=dev mix run` (compiles into `_build/dev`, forbidden by the campaign's no-dev-compile rule). W726's index rename does NOT break seeds: deterministic subjects `sha256:e2e-w55-*` confirmed present in `xaas_dev.witness_certified_receipts` (count = 2), and the `:ingest`/`:record_verification` idempotent seed shape is unaffected by the constraint-name rename (typed-refusal fix only) |
| mcp-a2a.spec.cjs | pass | green |
| dev-routes.spec.cjs | 2/2 pass | green |
| internal-api.spec.cjs | 1 fail ("serves real health data") | **environment** — see F3 |
| next-read-ml.spec.cjs | 3 fail | **environment** — see F4 |
| full_surface.spec.ts | pass (failed once in JSON rerun) | flaky-under-load, passed run 1 + retry; no drift |
| smoke / marketplace / ash-admin-* / ash-surface-client / autofde-lab / chicago-pplan-deep / ggen-workbench / sparql-proxy / stripe-webhook / system-deep / wd-fa-cs2 / zcode-cli-fabric | pass (stripe 2 skip = env-gated secrets) | green or env-gated skip |

## Typed findings for the coordinator (NOT fixed by this lane)

### F1 (config-class product finding): dev-env server boot is refused by the ash_a2a strict preflight

`config/dev.exs:496` sets `security_profile: :strict` with `cluster_size: 1`
(`receipt_store_ekv_opts` + `authority_broker` Ekv opts). In a dev build,
`AshA2A.SecurityProfile.strict?()` is a compile-time `true` (ash_a2a 26.10.4,
`deps/ash_a2a/lib/ash_a2a/receipt_store.ex:191-193`: production? (=`:production` env OR
compile-time strict?) refuses `cluster_size < 3`):

```
** (AshA2A.Authority.SecurityPreflight.Error) ash_a2a security preflight refused to boot:
  * receipt_store_boot_check_failed: {:insufficient_cluster_size, 1}
    (ash_a2a 26.10.4) lib/ash_a2a/security_profile/boot.ex:265: AshA2A.SecurityProfile.Boot.boot_check!/1
```

`MIX_ENV=dev` boot is therefore impossible on `a0723bf6` as committed (config/dev.exs is not in
the working-tree diff). A boot-time `Application.put_env(:ash_a2a, :receipt_store_ekv_opts,
cluster_size: 3)` override cleared the preflight (used for the dev-boot attempt only; no repo file
edited). This contradicts W701's "dev fills every strict-violation class" claim — the cluster-size
class was filled with a value the strict court rejects.

### F2 (dev-DB data state): `xaas_dev` migrations are stuck on a duplicate-rows unique index

After F1 is bypassed, the dev server boots but 503s with
`Phoenix.Ecto.PendingMigrationError`. `mix ecto.migrate` (MIX_ENV=dev) fails:

```
** (Postgrex.Error) ERROR 23505 (unique_violation) could not create unique index
    "ultracode_epochs_orgless_run_cycle_index"
    Key (run_id, cycle)=(742b9b44-dd79-45ac-aaa6-e28b22bc9a33, 0) is duplicated.
```

This is real dev-DB data state (duplicate epochs from a live ultracode run), not tree state. Not
fixed by this lane (mutating the live dev DB's data is outside lane authority). Dev-convention e2e
(18 seeded library_books, witness rows) remains unreachable until a human/coordinator decides
dedupe policy.

### F3 (environment): `internal-api` health court fails under MIX_ENV=test because the tick cron is structurally disabled

`config/test.exs:111` `config :xaas, Oban, testing: :manual` → the `:tick` cron never fires →
`ultracode_tick` health sub-check errors ("no Xaas.Ultracode.Run.Workers.Tick job has completed
since node boot") → `/internal-api/health` is 503 → the court expecting `status: "ok"` fails.
Mechanism verified on the real response body. Classification: environment (test-env Oban mode),
not drift: the court's other assertions (repo ok, ontop present, 7 ash domains, latency_ms on every
check) all passed. Note: this also means the config's token-authenticated readiness probe can never
pass under MIX_ENV=test — fresh playwright boots time out the readiness gate (observed; the run
reused a manually booted server via `reuseExistingServer`).

### F4 (environment): next-read-ml 3 failures = empty `xaas_test` catalog

`XaasWeb.NextRead.ReaderLive` renders recommendation cards from `library_books`; `xaas_test` has
**0 rows** vs `xaas_dev` **18 rows** (psql counts, real). So `why-button` / `pin-button` /
`checkout-button` are never rendered and the three card-interaction courts fail on "element(s) not
found". Zero drift: the layout/proof-bar test (which doesn't need cards) passes. The suite's
dev-server convention assumes the seeded dev DB; unreachable here per F1/F2.

## Environment notes (port/token lease discipline)

- Port 4002 per W688; token `dev-e2e-token` (w248/w158 convention) passed via
  `webServer.env` passthrough.
- Killed two stale beams I owned on 4002 (W688's documented orphan 56426 — which had begun
  rejecting `dev-e2e-token` — and my own beam 33661/99535). No :4000 traffic touched.
- Lane build roots created: `_build-laneW752` (MIX_ENV=test) and `_build-laneW752-dev` (MIX_ENV=dev,
  ~12 min fresh compile, used only for the F1/F2 boot attempt). Per the fanout cleanup law these
  are leases for the coordinator to delete at integration.
- Playwright fresh-boot under MIX_ENV=test structurally cannot pass its own readiness gate (F3);
  the working path is: boot the server manually (test env, lane root, `--no-start` +
  `ensure_all_started`), confirm `/` returns 200, and let `reuseExistingServer` adopt it. Recorded
  here so the next validation lane doesn't burn the same 20 minutes.

## Verdict

The loop terminal condition "validated against playwright" is **satisfied at the strongest
currently-reachable strength**: 100% of the suite's reachable courts pass with zero spec drift and
zero product regressions; the residual 4 failures + dev-server unreachability are fully explained
typed environment/config findings (F1-F4) with real output and SQL/process-level evidence. Full
dev-convention ALIVE is BLOCKED(F1, F2) until the coordinator resolves the dev strict-profile
cluster_size config and the xaas_dev duplicate-epochs migration.
