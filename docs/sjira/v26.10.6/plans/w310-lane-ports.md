# W310 — Playwright lane-lease ports (W279 cross-lane port-race fix)

Repo: /Users/sac/xaas (branch feat/playwright-surface, worktree, no commits made)
Date: 2026-10-06
Files owned/touched: `playwright.config.cjs` only (+ this receipt).

## Change

W279 flagged: concurrent Playwright lanes all bound :4000 (webServer `port`,
BOOT probe URL, app endpoint port all hard-coded 4000); with SO_REUSEPORT the
lanes stole each other's servers.

`playwright.config.cjs` now derives a single lane port from `PW_PORT`
(default 4000) and threads it through all three consumers:

1. `webServer.port` — Playwright's own readiness/ownership probe.
2. BOOT readiness probe (`PROBE_URL=http://localhost:${PW_PORT}...`).
3. `webServer.env.PORT` — the Phoenix endpoint itself binds via
   `config/runtime.exs` `System.get_env("PORT") || "4000"`, so without
   `PORT=$PW_PORT` the app still bound :4000 and every lane hit eaddrinuse
   (first verification run failed exactly this way; fixed and re-run).

Documented in the config header: concurrent lanes MUST set distinct
`PW_PORT` values; `PLAYWRIGHT_BASE_URL` must match the lane's port if set.
`baseURL` defaults to `http://localhost:${PW_PORT}`.

## Verification (real output, tokenless)

Two concurrent fresh-boot lanes on 4010 and 4011 (the live dev beam holds
:4000; per repo memory rule it was NOT killed — two fresh boots on 4010/4011
exercise the race path more strongly than the reuse-on-4000 variant anyway):

```
(PW_PORT=4010 npx playwright test e2e/smoke.spec.cjs --reporter=line ...) & \
(PW_PORT=4011 npx playwright test e2e/smoke.spec.cjs --reporter=line ...) & wait

EXIT4010=0
EXIT4011=0
/tmp/pw4010.log:Running 1 test using 1 worker
/tmp/pw4010.log:  1 passed (1.2m)
/tmp/pw4011.log:Running 1 test using 1 worker
/tmp/pw4011.log:  1 passed (1.7m)
eaddrinuse count in either log: 0
post-run listeners on 4010/4011: none (clean teardown)
```

Logs preserved at /tmp/pw4010.log, /tmp/pw4011.log.

## Standing

ALIVE — observed execution of the exact changed subject: two concurrent
fresh-boot Playwright lanes, distinct leased ports, both green, zero
eaddrinuse.
