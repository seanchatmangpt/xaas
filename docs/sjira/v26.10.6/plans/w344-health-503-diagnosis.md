# W344 — `/internal-api/health` 503-with-token residual diagnosis

Lane: W344, v26.10.6 convergence campaign. Repo `/Users/sac/xaas` @
`feat/playwright-surface` (read-only diagnosis; no lib/ or test/ edits).
Subject of the residual: w310g disclosed 503-with-valid-token; W310h landed
`check_ultracode_tick/0` warmup-window typing in
`lib/xaas_web/controllers/health_controller.ex`.

## Commands (real)

```bash
# 1. Fresh e2e-path boot + smoke spec (shared BOOT path, PW_PORT=4044)
PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=w344-token \
  PW_PORT=4044 npx playwright test e2e/smoke.spec.cjs --reporter=line
# -> "1 passed (56.8s)"; the BOOT readiness gate itself polls
#    /internal-api/health and requires 200 before the suite starts,
#    so the fresh boot already answered 200 with the token.

# 2. Standalone boot of the same server path (kept up for curl):
#    /tmp/w344-boot.sh replicates playwright.config.cjs BOOT
#    (global-setup --catalog; PHX_SERVER=true PORT=4044 mix run
#    'Application.put_env(:xaas, :marketplace_catalog_source, ...)' --no-halt,
#    log at /tmp/w344-server.log)

# 3. Health surface with token (first reachable moment after boot):
curl -s -o /tmp/w344-health.json -w '%{http_code}\n' \
  -H 'Authorization: Bearer w344-token' \
  http://localhost:4044/internal-api/health
# -> 200 (immediately at first reachable poll; no 503 window observed)
```

## Response body (HTTP 200)

```json
{"status":"ok","checks":{
 "ash_domain:accounts":{"count":3,"status":"ok"},
 "ash_domain:billing":{"count":1,"status":"ok"},
 "ash_domain:governance":{"count":0,"status":"ok"},
 "ash_domain:ledger":{"count":1,"status":"ok"},
 "ash_domain:marketplace":{"count":0,"status":"ok"},
 "ash_domain:operations":{"count":0,"status":"ok"},
 "ash_domain:platform":{"count":0,"status":"ok"},
 "ontop":{"reason":"not_configured","status":"skipped"},
 "repo":{"status":"ok"},
 "ultracode_tick":{"status":"ok","last_tick_at":"2026-10-06T23:36:01.641178Z","elapsed_minutes":0.0}}}
```

## Code-path correlation

`lib/xaas_web/controllers/health_controller.ex:178-225`
(`check_ultracode_tick/0`): last-tick predating node boot ->
`skipped (:warming_up)` until `stale_after_minutes + 2` minutes after boot,
then a real error. On this run the tick cron had already fired post-boot
(`last_tick_at` 23:36:01Z, `elapsed_minutes` 0.0 at 23:36Z), so the check
took the `{:ok, ...}` healthy branch directly — the warmup branch was not
even needed. Aggregate 200. Server log `/tmp/w344-server.log` tail shows the
per-domain `SELECT count(*)` probes OK and `Sent 200 in 33ms`.

## Verdict

**FIXED** — 200 with valid token at current tree, from the first reachable
moment on a fresh boot. No failing check; `ultracode_tick` is healthy
(post-boot tick present), so the W310h warmup guard is defense-in-depth
rather than load-bearing on this run. Not FLAKY-classified: single fresh
boot tested, immediate 200; the deterministic post-boot 503 mechanism
described at health_controller.ex:163-175 (pre-boot tick counted against
the 5-minute staleness window) is structurally removed by the W310h code.

## Cleanup

Killed only the beam I booted (`lsof -ti :4044` -> PID 33771, killed;
port 4044 clear). No repo-tree writes.
