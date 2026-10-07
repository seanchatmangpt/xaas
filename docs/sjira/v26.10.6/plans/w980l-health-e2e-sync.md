# W980l — internal-api health e2e: W836 contract sync check + real run

Lane W980l, v26.10.6 campaign, closes W752's internal-api failure class against
the W836 landed warming_up contract.

## Sync verdict: NO-OP (already synced)

`e2e/internal-api.spec.cjs` (W949's authored file) already asserts the W836
pinned contract — no stale 503-for-warming_up assertion exists:

- lines 94-107: aggregate 200 / `status:"ok"`; `ultracode_tick.status` in
  `["ok","skipped"]`; `skipped` ⇒ `reason:"warming_up"`; header comment cites
  `docs/sjira/v26.10.6/plans/w836-health-court.md` explicitly.
- Before/after: identical (no edit made; file was git-clean before and after).

## Real run (fresh playwright boot, tokened)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW980l \
  PW_PORT=4134 INTERNAL_API_TOKEN=w980l-token \
  npx playwright test e2e/internal-api.spec.cjs
```

Run tail:

```
[global-setup] marketplace catalog written: ... (13 packs)
[global-setup] W55_SEED_OK: witness rows seeded
[global-setup] W823_SEED_OK: next-read library fixtures seeded

Running 4 tests using 1 worker
  ✓ 1 refuses /internal-api/health without a token (fail-closed, typed body) (60ms)
  ✓ 2 refuses /internal-api/ocel_summary with an invalid token (401, typed body) (12ms)
  ✓ 3 serves real health data with the env token (22ms)
  ✓ 4 serves real OCEL summary data with the env token (30ms)
  4 passed (1.6m)
```

Note: first attempt failed — fresh `_build-laneW980l` required a full compile
and the 180s readiness probe expired (`last=000`). Precompiled
(`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW980l mix compile`, exit 0) and
reran: green. Lane build root deletion was permission-denied in this lane —
`_build-laneW980l` is left in place for coordinator cleanup (per lane
instruction "delete when done, else leave for coordinator").

## Standing

ALIVE — the tokened fresh-boot e2e passes 4/4 against the W836 warming_up
contract on branch feat/playwright-surface (HEAD 68a5c9f9 at run time).
W752's internal-api health failure class (stale 503 assertion) is closed:
no such assertion exists, and the fresh-boot run exercises the
`skipped(:warming_up)` grace path (boot well inside the 7-minute grace).

Not committed, per lane instruction.
