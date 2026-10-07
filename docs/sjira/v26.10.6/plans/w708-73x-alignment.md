# W708 — title_vi_xiii Art 73.x classification alignment (W641 finding #4)

Lane: W708, xaas v26.10.6, branch `feat/playwright-surface`, HEAD a0723bf6.
Not committed (coordinator owns commits). Files written:
test/eu_ai_act/title_vi_xiii_test.exs, this receipt.

## Defect

The Art 73 family deepening tests (73.1, 73.2, 73.2.s2, 73.3, 73.4, 73.5,
73.6 — 7 tests) asserted
`Enum.sort(report.classification) == [:INFRINGES_UNION_LAW, :MALFUNCTION]`
via the shared `art73_duty/0` and `art73_full/0` helpers. W679 (landed,
plans/w679-malfunction-fix.md) made `IncidentReport.build/2` suppress
`:MALFUNCTION` when the refusal atom is in the closed
`EuAiActAdmission.refusal_atoms/0` set, so real behavior is
`[:INFRINGES_UNION_LAW]` exactly — partition-exact, matching W538 and the
art12 court's `refute :MALFUNCTION in classification`.

## Change

Expectations aligned; no INPUT changed. Every row's input receipt is
`REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION` + `status: :refused` — an EUAIA-family
admission refusal — and each row evidences its corpus line's Art 73 reporting
seam (classification + typed-registry transmission / authority channels), not a
malfunction. Changing the input to a non-EUAIA infrastructure-fault receipt
would have changed what each row evidences; aligning the expectation preserves
intent.

- `art73_duty` (covers 73.2, 73.2.s2, 73.3, 73.6): expectation now
  `[:INFRINGES_UNION_LAW]`, comment cites W679/W708 rationale.
- `art73_full` (covers 73.1, 73.4, 73.5): same.

## Mutation rationale (W679 revert kill)

If W679's fix were reverted, `build/2` would again classify the
`status: :refused` EUAIA receipt as `:MALFUNCTION`, so the aligned assertion
`Enum.sort(report.classification) == [:INFRINGES_UNION_LAW]` (the exact-list
form that W679's 8-atom suppression loop also uses) fails — the mutant is
killed by all 7 tests. The aligned expectation is domain-correct because a
`REFUSED_EUAIA_*` atom is a lawful Art. 5(1) receipt-integrity refusal: the
admission layer working as designed is not a system malfunction. Non-EUAIA
refusals / bare errors still classify `:MALFUNCTION` (locked in
incident_report_test.exs tests 2-3, rerun green below).

## Verification (real runs, PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test,
MIX_BUILD_ROOT=_build-laneW708)

```
mix test test/eu_ai_act/title_vi_xiii_test.exs --include eu_ai_act
=> Finished in 4.0 seconds, Result: 476 passed  (exit 0)
```

(Tag convention: this file's evidenced tests carry only `@moduletag :eu_ai_act`
in `TitleVIXIIITest`; open-gap tests live in a separate module tagged
`:eu_ai_act_open_gap` only, so the include resolves cleanly. The run
exercises all Art 73 deepening rows.)

```
mix test test/xaas/semantics/incident_report_test.exs
=> Result: 9 passed  (exit 0)   [composition with W679 regression suite]
```

Lane build root `_build-laneW708`: deletion attempt REFUSED by session
permission system (both attempts) — left on disk for the coordinator per the
fanout cleanup law (coordinator deletes at integration).

## Standing

ALIVE — alignment observed on exact working-tree subject (HEAD a0723bf6 +
lane diff), both suites green, 476+9 real tests executed, mutation-revert kill
argued per W679's witnessed mutants (mutation A killed by the exact-list
assertion family this lane aligns to).
