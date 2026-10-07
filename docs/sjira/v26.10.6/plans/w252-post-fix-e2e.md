# W252 — Post-W171-fix consolidated e2e receipt

Date: 2026-10-06 · Repo: /Users/sac/xaas · Branch: feat/playwright-surface
Suite: `e2e/execution-fabric.spec.cjs e2e/system-deep.spec.cjs e2e/dev-routes.spec.cjs e2e/ash-admin-matrix.spec.cjs e2e/witness.spec.cjs e2e/full_surface.spec.ts`
Command: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test <suite> --reporter=json --workers=2`
Server: playwright-managed webServer (`PHX_SERVER=true mix run ... --no-halt`), token passed through via webServer.env.

## Adverse transport observations (before the admitted run)

Runs 1–3 were invalidated by environment, not by W171 fixes:

- Run 1: pre-existing stale beam(s) on :4000. This repo's endpoint binds with
  SO_REUSEPORT, so multiple beams can bind simultaneously; interleaved
  responses (some 503, some connection refused mid-run) produced 29/29
  failures. All :4000 pids killed (`lsof -ti :4000 | xargs kill -9`).
- Run 2: second webServer boot failed (ranch port held by run 1's beam) —
  results void.
- Run 3 (fresh single server, workers=2): 14 passed / 15 failed, with all 503s
  clustered in the first-executed tests and later tests on the same server
  returning 200 — classic boot-readiness race (playwright's url probe passed
  while the app still answered 503 during warm-up). Hypothesis tested by run 4.

## Admitted run (run 4, warm compile, clean port)

**Result: 28 passed / 1 failed (29 total), 0 skipped, 0 flaky. Duration 129s.**

| file | passed | failed |
|---|---|---|
| e2e/ash-admin-matrix.spec.cjs | 4 | 0 |
| e2e/dev-routes.spec.cjs | 2 | 0 |
| e2e/execution-fabric.spec.cjs | 3 | 0 |
| e2e/full_surface.spec.ts | 11 | 0 |
| e2e/system-deep.spec.cjs | 6 | 0 |
| e2e/witness.spec.cjs | 2 | 1 |

Per-W171-fix verification (all executed, all passing in run 4):

- execution/mcp typed JSON: execution-fabric 3/3 — actuate 403
  REFUSED(authority_ceiling:actuate) with env token, fail-closed 401 without,
  fabric probe 200 with actuate refusal in capabilities. PASS.
- LiveView chrome: system-deep 6/6 (header, twelve questions, standing chips,
  typed-empty tables, evidence sections, refresh coherence). PASS.
- actuate 403 body: covered by execution-fabric asserts. PASS.
- zoe card + PHX_SERVER boot: full_surface 11/11 including all surface HTTP
  status checks. PASS.

## Failure classification

1 real failure, test-side strictness artifact, not app breakage:

- `e2e/witness.spec.cjs:117 › renders real receipt rows when seeded, else the
  typed empty state` — assertion `toHaveText(/^(yes|no)$/)` at line 137. With a
  regex expectation Playwright matches the RAW cell text (no whitespace
  normalization on the regex path); the template renders the `<td
  data-testid="witness-receipt-verified">` cell with HTML indentation
  ("\n              no\n            "), so `^(yes|no)$` never matches despite
  the rendered value being correct ("no"). The adjacent test "at least the two
  deterministic seed rows are rendered" PASSED (both seed subjects present),
  proving the surface renders real rows. e2e/witness.spec.cjs is a W171
  lane-active file (mtime 2026-10-06). Fix direction (NOT applied, per
  lane scope): normalize in the test — `await expect(verified).toHaveText(
  /^\s*(yes|no)\s*$/)` or assert on `innerText` trimmed.

Pre-existing/environment-class (no W171 regression): boot-readiness 503 race
(see run 3) — recurring hazard; a readiness probe that accepts 503-as-warm-up
will keep poisoning first-wave results.

## Verdict

W171 fix class: verified ALIVE on exact subject (run 4, this checkout,
feat/playwright-surface). 1 residual test-side whitespace defect in
e2e/witness.spec.cjs:137. No product code defects surfaced. No fixes, no git
actions taken, per lane scope.

## Replay

```bash
lsof -ti :4000 | xargs -r kill -9; sleep 2
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token \
  npx playwright test e2e/execution-fabric.spec.cjs e2e/system-deep.spec.cjs \
  e2e/dev-routes.spec.cjs e2e/ash-admin-matrix.spec.cjs e2e/witness.spec.cjs \
  e2e/full_surface.spec.ts --workers=2
# expect: 28 passed, 1 failed (witness.spec.cjs:137 whitespace regex)
```
