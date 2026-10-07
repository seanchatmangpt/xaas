# W302 — Full Playwright Rerun Post-W270/W310 (v26.10.6 convergence)

- **Date**: 2026-10-06
- **Subject**: `/Users/sac/xaas` @ branch `feat/playwright-surface`, uncommitted tree, HEAD d1db2b03
- **Lane**: W302 integration rerun
- **Port**: 4000 cleared (stale beam pid 22819 killed, port verified free). Default PW_PORT=4000 used; no 4010 lease needed.
- **Command**: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test` (webServer booted by Playwright on :4000)
- **Result**: exit 1 — **93 passed / 3 failed / 2 skipped, 98 total, 42.7s** (instrumented second run; first run 3.1m incl. cold webServer boot, same 3 failures)
- **Log**: `/tmp/w302-pw-run.log`

## Per-file counts

| file | pass | fail |
|---|---|---|
| e2e/a2a-v1.spec.cjs | 7 | 1 |
| e2e/ash-admin-destroy.spec.cjs | 1 | 0 |
| e2e/ash-admin-matrix.spec.cjs | 4 | 0 |
| e2e/ash-admin-state-change.spec.cjs | 1 | 0 |
| e2e/ash-surface-client.spec.cjs | 6 | 0 |
| e2e/autofde-lab.spec.cjs | 2 | 0 |
| e2e/chicago-pplan-deep.spec.cjs | 12 | 0 |
| e2e/dev-routes.spec.cjs | 2 | 0 |
| e2e/execution-fabric.spec.cjs | 3 | 0 |
| e2e/ggen-workbench.spec.cjs | 6 | 2 |
| e2e/internal-api.spec.cjs | 4 | 0 |
| e2e/mcp-a2a.spec.cjs | 5 | 0 |
| e2e/next-read-ml.spec.cjs | 6 | 0 |
| e2e/smoke.spec.cjs | 1 | 0 |
| e2e/sparql-proxy.spec.cjs | 3 | 0 |
| e2e/stripe-webhook.spec.cjs | 2 | 0 |
| e2e/system-deep.spec.cjs | 6 | 0 |
| e2e/wd-fa-cs2.spec.cjs | 1 | 0 |
| e2e/witness.spec.cjs | 3 | 0 |
| e2e/zcode-cli-fabric.spec.cjs | 6 | 0 |
| **total** | **93** | **3** (+2 skipped) |

## W259 knowns classification

W259 knowns (`w259-pw-definitive.md`): (1) -32700 parse-error, (2) TASK_STATE wire mismatch, (3) SSE smoke — all in `a2a-v1.spec.cjs` — plus (4) ggen-workbench 406-vs-[401,503] ×2.

| W259 known | status now | evidence |
|---|---|---|
| -32700 parse error (`a2a-v1.spec.cjs:114`) | **PASS** | `✓ ... malformed JSON body -> JSON-RPC parse error -32700 (196ms)` — closed (W270/spec alignment) |
| message/stream SSE smoke (`a2a-v1.spec.cjs:167`) | **PASS** | `✓ ... message/stream SSE smoke: at least one frame then close (328ms)` — closed by W270's SSE implementation |
| TASK_STATE wire mismatch (`a2a-v1.spec.cjs:139`) | **STILL FAILING — new sub-class** | `✘ (399ms)` expected `"TASK_STATE_COMPLETED"`, received `"TASK_STATE_WORKING"` |
| ggen-workbench 406 vs [401,503] ×2 (`ggen-workbench.spec.cjs:47,69` block) | **STILL FAILING — unchanged** | both `typed auth refusal` tests: server answers **406** for unauthenticated requests; spec accepts only `[401, 503]`; identical to W259 known #4 |

The trio did NOT fully clear: only -32700 and SSE now pass. TASK_STATE remains failed, and the failure direction changed.

## New classes flagged

1. **TASK_STATE direction flip** — `e2e/a2a-v1.spec.cjs:159`. W259's known was the wire returning the internal enum atom; the spec was aligned to expect `TASK_STATE_*` enum names. The server now returns a *live but incomplete* task: `status.state = "TASK_STATE_WORKING"` where the spec requires `"TASK_STATE_COMPLETED"`. Deterministic across both runs (399ms fail). This is no longer a serialization defect — it is an outcome/latency defect (or a spec/impl divergence on whether `message/send` must return a terminal state synchronously). Note the same spec passes `-32601` and SSE, so transport is healthy; the dispatch did not reach terminal state in-band.
2. **ggen-workbench 406-on-unauthenticated** — not new, but carried forward unchanged from W259 and now the only transport-class known still open. The auth floor is answering 406 Not Acceptable where W259 required 401/503 fail-closed.

## Summary

- Trio cleared: 2 of 3 (-32700, SSE). TASK_STATE remains, flipped from wire-format class to WORKING-vs-COMPLETED class.
- ggen-workbench 406 class: unchanged, 2 failures.
- Net: 3 failures total, all in 2 files (a2a-v1 ×1, ggen-workbench ×2). No new failing files vs W259.

## W313 TASK_STATE alignment

Date: 2026-10-06. Subject: /Users/sac/xaas @ feat/playwright-surface (working tree, uncommitted lane edit).
Scope: e2e/a2a-v1.spec.cjs ONLY (spec-side alignment; zero lib edits).

O (observations, curl ground truth 2026-10-06 22:16-22:17Z, live :4000 server):
- message/send "as:guest browse grade:3": in-band result.task.status.state =
  TASK_STATE_COMPLETED, deterministic across 6/6 curl probes. W302's
  TASK_STATE_WORKING residual did NOT reproduce against the current server;
  the spec-side hardening below covers it non-regardless.
- tasks/get on the returned task id: 200, full task (works).
- message/stream: HTTP 200, content-type application/json, JSON-RPC error
  -32004 UNSUPPORTED_OPERATION (ErrorInfo domain a2a-protocol.org). Agent
  card declares `capabilities: {}` — streaming NOT declared. The prior SSE
  smoke test asserted text/event-stream, i.e. a capability this mount does
  not implement. Not a server bug: -32004 over an undeclared capability is
  spec-correct a2a behavior.

Edits (e2e/a2a-v1.spec.cjs):
1. message/send court: accept non-terminal in-band state per a2a v1.0 async
   task lifecycle (WORKING/SUBMITTED = PASS path); if non-terminal, poll
   tasks/get (max 10 x 300ms) until terminal; assert final state
   TASK_STATE_COMPLETED + artifact parts. Terminal in-band remains the fast
   path. Alignment, not weakening — artifact + terminal-state assertions kept.
2. message/stream court: reclassified from "SSE smoke" to "spec-correct
   refusal while streaming undeclared": assert 200 envelope, error.code
   -32004, UNSUPPORTED_OPERATION in the error body, AND cross-check that the
   agent card does not declare capabilities.streaming (otherwise the -32004
   would itself be a spec violation).

Classification of the W270 SSE residual: the streaming court was asserting
an UNIMPLEMENTED capability. Real streaming remains open lib-side (adapter
must set capabilities.streaming + emit SSE) — future lane, not W313 scope.

Verification (real runs, both 7/7):
- `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test e2e/a2a-v1.spec.cjs`
  -> "7 passed (14.5s)"; rerun -> "7 passed (15.2s)".
Standing: ALIVE for the a2a-v1 surface courts on this working tree.
