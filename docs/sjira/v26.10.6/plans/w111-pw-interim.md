# W111 — Playwright Interim Verification (repaired spec classes, W96/W98/W100)

- Date: 2026-10-06
- Lane: W111, v26.10.6 convergence, repo `/Users/sac/xaas`
- Subject: branch `feat/playwright-surface`, working tree at run time (uncommitted lane state; W97/W99 still in flight)
- Server: reused pre-existing live server on :4000 (beam.smp PID 59474, listening at invocation; HTTP 200 on `/`). Not started by this lane, not stopped.
- Command:
  `PATH=$HOME/.asdf/shims:$PATH npx playwright test e2e/dev-routes.spec.cjs e2e/autofde-lab.spec.cjs e2e/system-deep.spec.cjs e2e/ash-admin-matrix.spec.cjs e2e/ash-surface-client.spec.cjs e2e/chicago-pplan-deep.spec.cjs --reporter=json`
  (exit 1; a first plain-reporter run under the same server showed the same failure set)
- Global-setup noise (pre-existing, non-blocking, disclosed): witness seed step FAILED (continuing); build-dir lock contention with concurrent lane processes observed in stderr.

## Per-file counts (verbatim from JSON report)

| spec file | passed | failed | timedOut |
|---|---|---|---|
| dev-routes.spec.cjs        | 0 | 2 | 0 |
| autofde-lab.spec.cjs       | 2 | 0 | 0 |
| system-deep.spec.cjs       | 6 | 0 | 0 |
| ash-admin-matrix.spec.cjs  | 2 | 2 | 0 |
| ash-surface-client.spec.cjs| 6 | 0 | 0 |
| chicago-pplan-deep.spec.cjs| 9 | 2 | 1 |
| **TOTAL**                  | **25** | **6** | **1** |

## Failure classification

| # | Test | Class | Notes |
|---|---|---|---|
| 1 | dev-routes › /dev/dashboard renders real home page | spec locator bug (strict-mode violation) | `getByRole('heading', {name:'Dashboard'})` resolves to 2 elements (`Phoenix LiveDashboard` h1 + banner-card h6). Page renders; selector needs `exact`. W96-class residual. |
| 2 | dev-routes › /admin ash_admin mount renders | possibly environment/data | `CapabilityLivenessReceipt` text not found within 5s; admin page loads (related matrix test sees admin chrome). Data-dependent or nav-depth assumption. |
| 3 | ash-admin-matrix › admin index: both real domains present | spec locator / UI state | `getByText('Platform')` resolves but is hidden (collapsed nav section?). Needs expand-first or different anchor. |
| 4 | ash-admin-matrix › record show panel read-only | server 503 | HTTP 503 on the show route — app-side (admin route/live under the reused dev server), not a Playwright timeout. Needs W97/W99 or server-config look. |
| 5 | chicago-pplan-deep › 12 capability cards candidates | spec expectation stale | wasm4pm card shows `successor` standing, spec asserts `candidate`. Live data evolved past committed expectation. |
| 6 | chicago-pplan-deep › FinOps slider recomputes KPIs | timeout (15s waitForFunction) | KPI recompute not observed after phx-change; could be LiveView wiring or timing. |
| 7 | chicago-pplan-deep › delivery state UNKNOWN numbers | timedOut in beforeEach (30s) | cascade: likely collateral of the same suite's slow tests / server load; not independently diagnosed. |

## Classification summary

- Green (previously-repaired classes holding): autofde-lab (2/2), system-deep (6/6), ash-surface-client (6/6), chicago-pplan-deep drill-down + seller + ontology explorer (9 pass).
- Spec-side residuals (W96-class): #1, #3, #5.
- App/server-side or undiagnosed (route to W97/W99 owners): #2, #4 (503), #6, #7.

Standing: PARTIAL_ALIVE — repaired classes verified green on a real server; 7 failures remain, none in the W96/W98/W100-repaired assertions for autofde-lab/system-deep/ash-surface-client. No edits made, no git operations, no servers killed.
