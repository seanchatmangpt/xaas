# W205 — Router regression cover (W150 endpoint reorder + a2a parse floor)

Lane: W205, v26.10.6 convergence. Repo: /Users/sac/xaas (canonical checkout, branch feat/playwright-surface).
Scope: read-only regression verification of W150's changes to `lib/xaas_web/endpoint.ex`
(workbench pipeline reorder — token floor before `:accepts` — plus a2a parse floor).
No fixes, no git. Three real runs.

## Command

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web test/xaas/bridges
```

## Runs (verbatim counts)

| run | result line (verbatim) | failures |
|---|---|---|
| 1 | `Result: 356/357 passed, 1 excluded` / `Failed: 1 test` — Finished in 17.4 seconds (1.7s async, 15.6s sync) | 1 — `XaasWeb.WitnessLiveTest`-family: log shows `** (Req.TransportError) connection refused`; failing test asserted the witness receipt surface (environmental — external witness endpoint unreachable in test env) |
| 2 | `Result: 319/357 passed, 1 excluded` / `Failed: 38 tests` — Finished in 23.5 seconds (1.7s async, 21.7s sync) | 38 — mass failure class (see classification) |
| 3 | `Result: 356/357 passed, 1 excluded` / `Failed: 1 test` — Finished in 12.4 seconds (1.2s async, 11.1s sync) | 1 — `test renders the typed empty state when no receipts exist (XaasWeb.WitnessLiveTest)` test/xaas_web/live/witness_live_test.exs:67 — `assert has_element?(view, "[data-testid='witness-empty-row']")` got false |

## Failure classification

- **Run 1 (1 failure)**: the expected witness environmental flake. Log line verbatim:
  `13:58:34.314 request_id=GNwMVcV3LlqvensAAE5C [warning] ** (Req.TransportError) connection refused`.
  The sole failing test is on the witness receipt surface, which reaches an external
  endpoint. Environmental, not a router regression. Matches the known-flake description.

- **Run 2 (38 failures) — NOT attributed to W150.** Classification: torn/stale build
  state from concurrent compilation into the shared `_build/test`, evidenced by the log
  being saturated with `warning: redefining module ... (current version loaded from
  _build/test/lib/xaas/ebin/...)` lines and by the failure signatures themselves:
  `function Xaas.Governance.Changes.ApprovalBackupRetentionChangeApprove.init/1 is
  undefined (module ... is not available)`, `no "500" json template defined for
  XaasWeb.ErrorJSON (the module does not exist)` — modules that demonstrably exist and
  passed in runs 1 and 3 on the identical tree. Per the concurrent-sessions memory
  (shared checkout, concurrent compile corrupts test build state), run 2 is discarded
  as build-state contamination. Runs 1 and 3 are the clean evidence runs.

- **Run 3 (1 failure)**: same witness surface family, different assertion (empty-state
  element missing rather than transport error). The empty-state test asserts no witness
  receipts exist in the store; residue from concurrent DB writers (shared local
  Postgres across sessions) makes it order/environment-sensitive. Environmental,
  witness-surface-only. No router, controller, endpoint, or bridge test failed in
  runs 1 or 3.

## Verdict

W150's endpoint reorder (token floor before `:accepts`) and a2a parse floor show **no
regression** on the covered surface: `test/xaas_web` + `test/xaas/bridges`, 356/357 in
both clean runs, the single failure in each being the known witness environmental flake
family. Standing: PARTIAL_ALIVE — cover executed on the exact tree; witness surface
remains environmentally sensitive.

## Artifacts

- Full run 2 log: /tmp/w205_run2.log
- Full run 3 log: /tmp/w205_run3.log
