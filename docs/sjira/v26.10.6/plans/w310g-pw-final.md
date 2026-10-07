# W310g — Final Full Playwright Receipt (v26.10.6 convergence)

- Lane: W310g (integration), repo `/Users/sac/xaas`, branch `feat/playwright-surface`
- Subject: working tree post W150/W171/W174/W270/W280/W299c/W305 + format sweep + PHX_SERVER + readiness probe + stderr redirect + PW_PORT lease
- Date: 2026-10-06
- Command: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test` (full log preserved at `/tmp/w310g-pw-full.log`)
- Precondition: port :4000 cleared (all beams killed — authorized by order); server launched by Playwright webServer (PHX_SERVER + readiness probe + stderr redirect + PW_PORT lease)

## Summary

**95 passed / 1 failed / 2 skipped — 98 total, 34.4s, npx exit 1.**

## Per-file counts

| file | total | passed | failed | skipped |
|---|---|---|---|---|
| e2e/chicago-pplan-deep.spec.cjs | 12 | 12 | 0 | 0 |
| e2e/full_surface.spec.ts | 11 | 11 | 0 | 0 |
| e2e/a2a-v1.spec.cjs | 7 | 7 | 0 | 0 |
| e2e/zcode-cli-fabric.spec.cjs | 6 | 6 | 0 | 0 |
| e2e/system-deep.spec.cjs | 6 | 6 | 0 | 0 |
| e2e/next-read-ml.spec.cjs | 6 | 6 | 0 | 0 |
| e2e/ggen-workbench.spec.cjs | 6 | 6 | 0 | 0 |
| e2e/ash-surface-client.spec.cjs | 6 | 6 | 0 | 0 |
| e2e/mcp-a2a.spec.cjs | 5 | 5 | 0 | 0 |
| e2e/stripe-webhook.spec.cjs | 4 | 2 | 0 | 2 |
| e2e/marketplace.spec.ts | 4 | 4 | 0 | 0 |
| e2e/internal-api.spec.cjs | 4 | 3 | 1 | 0 |
| e2e/ash-admin-matrix.spec.cjs | 4 | 4 | 0 | 0 |
| e2e/witness.spec.cjs | 3 | 3 | 0 | 0 |
| e2e/sparql-proxy.spec.cjs | 3 | 3 | 0 | 0 |
| e2e/execution-fabric.spec.cjs | 3 | 3 | 0 | 0 |
| e2e/dev-routes.spec.cjs | 2 | 2 | 0 | 0 |
| e2e/autofde-lab.spec.cjs | 2 | 2 | 0 | 0 |
| e2e/wd-fa-cs2.spec.cjs | 1 | 1 | 0 | 0 |
| e2e/smoke.spec.cjs | 1 | 1 | 0 | 0 |
| e2e/ash-admin-state-change.spec.cjs | 1 | 1 | 0 | 0 |
| e2e/ash-admin-destroy.spec.cjs | 1 | 1 | 0 | 0 |
| **total** | **98** | **95** | **1** | **2** |

## Failure (verbatim)

```
1) e2e/internal-api.spec.cjs:82:3 › /internal-api token gate › serves real health data with the env token

  Error: expect(received).toBe(expected) // Object.is equality

  Expected: 200
  Received: 503

    86 |       headers: authHeaders(TOKEN),
    87 |     });
  > 88 |     expect(res.status()).toBe(200);
       |                          ^
    89 |
    90 |     const body = await res.json();
    91 |     expect(body.status).toBe("ok");
      at /Users/sac/xaas/e2e/internal-api.spec.cjs:88:26
```

Error context: `test-results/internal-api--internal-api-ce43b-lth-data-with-the-env-token/error-context.md`

## Failure classification (isolation rerun)

`npx playwright test e2e/internal-api.spec.cjs` in isolation → **same failure reproduces:
1 failed, 3 passed (14.3s, exit 1).** Classification: **REAL, not a flake.**

- The token gate itself is fine: sibling test "serves real OCEL summary data with the env
  token" (same file, same token, same authHeaders helper) passes in both runs.
- `GET /internal-api/health` with the env token returns **503** where the test expects 200
  with `body.status == "ok"`. This is a server-side health-endpoint behavior (endpoint
  reporting not-ok/unhealthy under the current dev server state), not auth, not transport,
  not test flake.
- Per order: no fixes applied.

## Skipped (2, by design)

- `e2e/stripe-webhook.spec.cjs:87` — rejects a signature computed over a tampered body (typed 400)
- `e2e/stripe-webhook.spec.cjs:120` — accepts a real well-formed signature over the exact body (200, acked)

Both require a real Stripe signing secret; skipped in this environment.

## Standing

- Full-suite ALIVE except one real defect: `/internal-api/health` returns 503 with the env
  token where the court expects 200/ok. All other 95 executable tests pass on this exact
  subject; the 2 skips are environment-gated Stripe signature tests, not failures.
