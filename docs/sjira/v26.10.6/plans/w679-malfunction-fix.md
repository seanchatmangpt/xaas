# W679 — IncidentReport :MALFUNCTION misclassification fix

Lane: W679, xaas v26.10.6, branch `feat/playwright-surface`, HEAD a0723bf6. Not committed (coordinator owns commits).

## Defect (from W658c)

`IncidentReport.maybe_add_malfunction/3` classified any receipt with
`status: :refused`/`:error` as `:MALFUNCTION` even when the receipt's typed
refusal atom was a lawful `REFUSED_EUAIA_*` Art. 5(1) admission refusal —
contradicting the moduledoc row ("carrying any **other** refusal atom"). The
admission layer working as designed was being reported as a malfunction.

## Fix (lib/xaas/semantics/incident_report.ex)

- Compile-time `@euaia_refusal_strings` MapSet built by reusing the exposed
  closed set `Xaas.Semantics.EuAiActAdmission.refusal_atoms/0` (no duplicated
  atom list).
- `maybe_add_malfunction/3`: a refusal atom in the closed EUAIA set now
  suppresses `:MALFUNCTION`, both for the refusal-atom clause and the
  `status: :refused`/`:error` clause. Non-EUAIA refusals and bare error
  statuses still classify `:MALFUNCTION` (moduledoc unchanged — it already
  specified "any other refusal atom").

## Regression tests (test/xaas/semantics/incident_report_test.exs)

New describe block "EUAIA admission refusals are not MALFUNCTION (W679 regression)":

1. All 8 `EuAiActAdmission.refusal_atoms()` with `status: :refused` →
   `classification == [:INFRINGES_UNION_LAW]` exactly.
2. Non-EUAIA refusal (`:REFUSED_INFRASTRUCTURE_FAULT`) + `status: :refused` →
   `[:MALFUNCTION]` exactly.
3. Bare `status: :error`, no refusal atom → `[:MALFUNCTION]` exactly.

## Mutation kills (real runs, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW679)

- Mutation A (revert to original logic): `8/9 passed, Failed: 1` — killed by
  the all-8-atoms loop test. Test 2 survives mutation A (the original logic
  also classified it :MALFUNCTION) — it is a directional lock against the
  reverse mutation.
- Mutation B (`malfunction? = false`, over-broad exclusion): `5/9 passed,
  Failed: 4` — killed by tests 2 and 3 (and others). Both mutation directions
  are covered; neither mutant survives. Fixed version restored and verified
  byte-identical (`diff` clean).

## Cross-lane coordination (W658c)

`test/xaas/semantics/art12_chain_court_test.exs` (b) receipt omits `status`,
so it was never on the faulty path; rerun after fix: green.

## Verification (real tails, exit 0)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW679 \
  mix test test/xaas/semantics/incident_report_test.exs \
           test/xaas/semantics/art12_chain_court_test.exs
=> Result: 18 passed   (exit 0)
```

Lane build root `_build-laneW679` deleted after final run.

## Standing

ALIVE — fix observed on exact working-tree subject (uncommitted, HEAD a0723bf6
+ lane diff), both test files green, both mutants killed. Files written:
lib/xaas/semantics/incident_report.ex, test/xaas/semantics/incident_report_test.exs,
this receipt.
