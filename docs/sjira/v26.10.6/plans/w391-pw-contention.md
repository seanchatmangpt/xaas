# W391 — PW contention adjudication (v26.10.6)

Re: w381-pw-skips-adjudication.md (86 expected / 10 unexpected vs w317's 96/0).

## The 10 unexpected (from w381)

8 files, 10 failed tests:

1. `e2e/ash-admin-destroy.spec.cjs:55` — "ash_admin: destroy a real CapabilityLivenessReceipt row and see it genuinely gone"
2. `e2e/ash-admin-state-change.spec.cjs:26` — "ash_admin: create a real CapabilityLivenessReceipt CapabilityLivenessReceipt row and see it persist"
3. `e2e/chicago-pplan-deep.spec.cjs:194/256` — chicago-pplan-deep
4. `e2e/full_surface.spec.ts:82` — "catalog search narrows results and clears back"
5. `e2e/next-read-ml.spec.cjs:64`
6. `e2e/system-deep.spec.cjs:98`
7. `e2e/wd-fa-cs2.spec.cjs:5`
8. `e2e/zcode-cli-fabric.spec.cjss:131`

## Isolated rerun (fleet drained; PW_PORT=4091)

`PATH=$HOME/.asdf/shims:$PATH PW_PORT=4091 INTERNAL_API_TOKEN=w391-token npx playwright test <the 8 files>` →
**41 passed / 3 failed (2.8m)**. 7 of 8 files fully green: chicago-pplan-deep,
next-read-ml, system-deep, wd-fa-cs2, zcode-cli-fabric (all contention, not regression).

## Mid-run contamination event (not a regression)

A second run on PW_PORT=4092 collapsed (full_surface 10/10 red, app-wide
"Compilation error" 500s): another lane's in-flight edit to `lib/xaas/vault.ex`
(w393's OS-17 fail-closed prod-key change) left the file syntactically broken
(`TokenMissingError, lib/xaas/vault.ex:41 missing terminator: end`) while the PW
server booted. The file has since been completed on disk and is now valid; a
third run (PW_PORT=4093) with vault.ex settled: **11 passed / 2 failed (1.4m)** —
full_surface.spec.ts fully green including :82. That second run is discarded as
cross-lane contamination, logged here so the failure is attributed, not lost.

## Verdict: PARTIAL

- **CONTENTION-CONFIRMED for 8 of 10**: next-read-ml:64, system-deep:98,
  wd-fa-cs2:5, zcode-cli-fabric:131, chicago-pplan-deep:194/256, full_surface:82
  all pass in isolation. w317's full-suite receipt stands as authoritative green.
- **REAL REGRESSION (deterministic, 3/3 runs + w381): the two ash-admin specs**
  — `ash-admin-destroy.spec.cjs:55` and `ash-admin-state-change.spec.cjs:26`.
  Failure signature (identical both specs, all runs): the ash_admin `:ingest`
  form flow completes without UI expect failure, Save submits, but the row never
  persists — the internal-api follow-up returns 200 with `data: []`
  (`Expected length: 1, Received length: 0`). No visible form/validation error in
  the page snapshot. Both specs share the create-via-admin-UI step, so the
  broken step is the admin-UI create path for CapabilityLivenessReceipt
  (plausibly touched by recent EA34/EA35 ash-surface commits; not diagnosed
  further — outside lane scope).

## Receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface, w391 lane, PW ports 4091/4092/4093
- Commands: three isolated `npx playwright test` runs as recorded above
- Isolated counts: 41/3 (run 1), discarded contamination run, 11/2 (run 3)
- Standing: PARTIAL — 8/10 contention-confirmed; 2 deterministic real failures
  in the ash-admin CapabilityLivenessReceipt create-via-admin path.
