# W347 — ggen-workbench auth-floor re-witness receipt

Branch: feat/playwright-surface (canonical checkout /Users/sac/xaas, no commits made).
Re-witness of W299c's /api forward scope reorder: tokenless must answer typed 401, never 406.

## 1. Unit court

Command (real paths on this tree — the controller spec is
`execution_fabric_surface_test.exs`, not `execution_fabric_controller_test.exs`):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW347 \
  mix test test/xaas_web/plugs/require_internal_api_token_test.exs \
           test/xaas_web/controllers/execution_fabric_surface_test.exs \
           test/xaas_web/ggen_workbench_auth_floor_test.exs
```

Real output (tail):

```
.................
Finished in 2.9 seconds (0.00s async, 2.9s sync)
Result: 17 passed
[exited with code 0]
```

## 2. Live wire

Boot: `PORT=4047 PW_PORT=4047 PHX_SERVER=true INTERNAL_API_TOKEN=w347-token` +
`mix run --no-halt` (playwright-config BOOT sequence, dev env). Readiness probe `/` → 200.
Then `PW_PORT=4047 npx playwright test e2e/smoke.spec.cjs` → `1 passed (1.5m)`.
Server booted WITH `INTERNAL_API_TOKEN=w347-token`; curls run WITHOUT any auth header,
so this is the wrong-token/missing-token 401 branch, not the unset-env 503 branch.

Tokenless 3-code vector:

```
401 /api/workbench/ggen/health content-type=application/json; charset=utf-8
  {"error":"unauthorized","detail":"missing or invalid Bearer token"}
401 /api/workbench/ggen content-type=application/json; charset=utf-8
  {"error":"unauthorized","detail":"missing or invalid Bearer token"}
401 /internal-api/health content-type=application/json; charset=utf-8
  {"error":"unauthorized","detail":"missing or invalid Bearer token"}
```

Matches the matrix's expected cells (tokenless → typed JSON 401 on all three surfaces).

## 3. Verdict

**406 class CLOSED (re-witnessed at current tree).** No 406 observed anywhere; every
tokenless response is `application/json` typed 401 with a Bearer-token detail.

## Cleanup

- Server killed: PID 73309 (`lsof -ti :4047` → clear).
- `rm -rf /Users/sac/xaas/_build-laneW347` DENIED by session permission gate —
  path remains on disk: `/Users/sac/xaas/_build-laneW347` (coordinator to delete).
