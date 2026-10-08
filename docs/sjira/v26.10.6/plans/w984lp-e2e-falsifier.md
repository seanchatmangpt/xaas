# W984lp — W984fw falsifier executed: Playwright pipeline no longer writes xaas_test

Date: 2026-10-08 · Lane: W984lp · Branch: feat/playwright-surface · NO commit

## Falsifier (from w984fw-seed-writer.md)

`MIX_ENV=test PW_PORT=4199 npx playwright test e2e/next-read-ml.spec.cjs` must
produce 0 new committed rows in `xaas_test.library_curations` — the server must
boot dev (xaas_dev) regardless of inherited MIX_ENV=test.

## Commands (real, from /Users/sac/xaas)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test PW_PORT=4199 npx playwright test e2e/next-read-ml.spec.cjs
```

Run 1: webServer readiness probe timed out (fresh dev compile exceeded the 180s
probe window; the server came up on 4199 shortly after and was reused for run 2).
Run 2 (warm server reuse, `reuseExistingServer: true`):

```
Running 6 tests using 1 worker
  ✓ 1 renders dual-persona layout ... (9.4s)
  ✓ 2 expands grounded 'Why this one?' explainability drawer ... (1.5s)
  ✓ 3 librarian pin action dynamically updates curation and student card spotlight (3.0s)
  ✓ 4 executes student checkout ... (2.0s)
  ✓ 5 executes 'Ask the Catalog' natural language semantic search ... (2.8s)
  ✓ 6 switches between split, student-only, and librarian-only view modes (2.2s)
  6 passed (53.7s)
EXIT=0
```

The writer test (#3, the toggle_pin click that caused W650h23) executed and passed.

## Counts (psql, real)

| DB | before | after | delta |
|---|---|---|---|
| xaas_test.library_curations | 1 | 1 | 0 |
| xaas_dev.library_curations | 46 | 47 | +1 |

`xaas_dev` delta +1 (row with `inserted_at > now()-15min` = 1) proves the pin
click actually wrote during the run — into xaas_dev, not xaas_test.

## Verdict

**PASS** — xaas_test delta == 0 while the writer test clicked and committed into
xaas_dev. The W984fw pinned-MIX_ENV=dev fix holds under the exact
inherited-MIX_ENV=test attack it was built for.

## Side observations (pre-existing, not fixed by this lane)

- `[global-setup] library seed did not report W823_SEED_OK (continuing)`:
  `MIX_ENV=dev mix run e2e/seed-library.exs` now fails at
  `Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :auto)` (seed-library.exs:26) — the
  dev Repo is not in sandbox :manual mode, so the flip raises. Failure-tolerant
  setup continues; fixtures pre-existed in xaas_dev (46 rows). Open follow-up for
  the seed owner: guard the Sandbox.mode calls behind `Mix.env() == :test`.
- First-boot readiness: a cold dev compile can exceed the 180s BOOT probe
  (observed once; second run reused the server). Not a W984fw regression.

## Cleanup

Lane server (beam PID 83759, port 4199) killed and verified DEAD
(`probe_after_kill=000`). No other lanes' processes touched. No files modified
except this receipt.
