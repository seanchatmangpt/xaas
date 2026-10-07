# W299 — Definitive Final Playwright Receipt (v26.10.6 convergence)

- Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface`, working tree (uncommitted state, no fixes applied by this lane)
- Date: 2026-10-06
- Suite: `npx playwright test`, full suite, 98 tests, 8 workers, port :4000
- Env: `PATH=$HOME/.asdf/shims:$PATH`, `INTERNAL_API_TOKEN=dev-e2e-token`, PW 1.63.0, node 24.15, macOS 26.2 arm64
- Full output archived at `docs/sjira/v26.10.6/plans/w299-pw-run2-full.log` (run 2 = classification run; run 1 archive `/tmp/w299_pw_full.log`)

## Run history

| run | result |
|---|---|
| 1 (fresh boot after killing all beams on :4000) | **7 passed / 89 failed / 2 skipped** (2.0m) — server died at test ~5 (first a2a-v1 GET: `socket hang up`); every subsequent test `ECONNREFUSED` |
| 2 (fresh boot, classification pass) | **73 passed / 23 failed / 2 skipped** (2.9m) — server survived most of the suite, died again near the end (zcode-cli-fabric `initialize`: `socket hang up`, then `ECONNREFUSED`) |
| 3 (isolated re-run of the 4 server-up assertion failures) | **13 passed / 2 failed** (26.2s) — see classification |

## Per-file counts (run 2, the classification run)

| file | passed | failed | skipped |
|---|---|---|---|
| e2e/a2a-v1.spec.cjs | 6 | 1 | |
| e2e/ash-admin-destroy.spec.cjs | 0 | 1 | |
| e2e/ash-admin-matrix.spec.cjs | 4 | 0 | |
| e2e/ash-admin-state-change.spec.cjs | 0 | 1 | |
| e2e/ash-surface-client.spec.cjs | 6 | 0 | |
| e2e/autofde-lab.spec.cjs | 2 | 0 | |
| e2e/chicago-pplan-deep.spec.cjs | 6 | 6 | |
| e2e/dev-routes.spec.cjs | 2 | 0 | |
| e2e/execution-fabric.spec.cjs | 3 | 0 | |
| e2e/full_surface.spec.ts | 10 | 1 | |
| e2e/ggen-workbench.spec.cjs | 4 | 2 | |
| e2e/internal-api.spec.cjs | 4 | 0 | |
| e2e/marketplace.spec.ts | 4 | 0 | |
| e2e/mcp-a2a.spec.cjs | 5 | 0 | |
| e2e/next-read-ml.spec.cjs | 2 | 4 | |
| e2e/smoke.spec.cjs | 1 | 0 | |
| e2e/sparql-proxy.spec.cjs | 3 | 0 | |
| e2e/stripe-webhook.spec.cjs | 2 | 0 | 2 |
| e2e/system-deep.spec.cjs | 5 | 1 | |
| e2e/wd-fa-cs2.spec.cjs | 1 | 0 | |
| e2e/witness.spec.cjs | 0 | 3 | |
| e2e/zcode-cli-fabric.spec.cjs | 3 | 3 | |
| **TOTAL** | **73** | **23** | **2** |


## Failures — verbatim + classification

### A. Real, reproducible in isolation (2)

**1–2. e2e/ggen-workbench.spec.cjs:47:5 — `typed auth refusal without token: /api/workbench/ggen/health` and `: /api/workbench/ggen`**

```
Error: expect(received).toContain(expected) // indexOf
Expected value: 406
Received array: [401, 503]
> 49 |  expect([401, 503]).toContain(noAuth.status());
```

Verbatim observed: tokenless `GET /api/workbench/ggen` (Accept: application/json) returns **406 Not Acceptable** instead of the contracted typed 401/503 refusal. Reproduced identically in the isolated run 3. This is a **real defect** (misclassification gate: the auth floor answers 406 content-negotiation failure before the token gate answers, on this mount). No fix applied per lane scope.

### B. Flake (pass in isolation, 3)

- `e2e/a2a-v1.spec.cjs:139:3` message/send happy path — run 2 verbatim: `Expected: "TASK_STATE_COMPLETED" / Received: "TASK_STATE_WORKING"` at a2a-v1.spec.cjs:159. Passed in isolation (run 3). Read-after-dispatch timing race: task not yet completed when the sync response is asserted.
- `e2e/ash-admin-state-change.spec.cjs:26:1` — run 2 verbatim: `expect(body.data).toHaveLength(1) → Received length: 0` at :83. Passed in isolation. Read-after-write visibility race (admin create → immediate internal-api read).
- `e2e/ash-admin-destroy.spec.cjs:55:1` — run 2 verbatim: same shape, `expect(beforeBody.data).toHaveLength(1) → Received length: 0` at :90. Passed in isolation.

### C. Infrastructure: server process death mid-suite (18, both runs)

The Phoenix server died mid-run in BOTH runs, at a different point each time (run 1: during first a2a-v1 agent-card GET, "socket hang up"; run 2: during zcode-cli-fabric `initialize` POST, "socket hang up", then mass `ECONNREFUSED` / one `ERR_EMPTY_RESPONSE`). Every failure below is a transport failure caused by that death, not a surface assertion:

Run 2 list (all `net::ERR_CONNECTION_REFUSED` at the spec's goto/post unless stated):
- chicago-pplan-deep 287:3 (this one: `waitForFunction ... phx-connected` Timeout 15000ms immediately before the death), 296, 308, 325, 349, 365 (5× marketplace-pplan ECONNREFUSED)
- full_surface 117:3 (ERR_EMPTY_RESPONSE at /marketplace-catalog)
- next-read-ml 64, 91, 127, 147 (4× ECONNREFUSED)
- system-deep 327 (ECONNREFUSED)
- witness 109, 117, 146 (3× ECONNREFUSED)
- zcode-cli-fabric 172 (socket hang up — the death point), 204, 224 (ECONNREFUSED)

Run 1's 89 failures were the same class: one early server death poisoning the remaining 85 specs (full per-test verbatim in the run-1 archive `/tmp/w299_pw_full.log`).

**This server-death recurrence is itself a real open defect** (2/2 runs): the web VM dies mid-suite on these execution surfaces. First suspect by coincidence in both runs: `/a2a/v1` and `/internal-api/execution/mcp` request handling. Not investigated further in this lane (no fixes).

## Standing

- ALIVE: 73/98 suite green on the classification run; the full read surface (admin matrix, internal-api gates, marketplace, mcp-a2a, sparql, stripe-webhook, smoke, wd-fa, ash-surface-client, autofde-lab, dev-routes, execution-fabric) passes.
- BLOCKED (server-death defect): witness (3), zcode-cli-fabric with-token surface (3), chicago-pplan marketplace-pplan section (5), next-read-ml (4), system-deep Refresh, full_surface journey — all transport-only.
- Real defect, 1: ggen-workbench tokenless auth floor returns 406 instead of typed 401/503 (reproducible; `e2e/ggen-workbench.spec.cjs:49` and `:63`).
- Flakes, 3: a2a-v1 task-state timing; ash-admin create/destroy read-after-write visibility (x2).
- 2 skipped: stripe-webhook tampered-body + well-formed-signature (pre-existing skip markers, unchanged by this lane).
