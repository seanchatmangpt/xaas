# W981p — Open-GAP Mutation Hardening (anti-vacuity pass on W650c OPEN_GAP rows)

Lane: W981p, xaas v26.10.6 campaign, 2026-10-07. Subject: branch
`feat/playwright-surface`, working tree (uncommitted), with the three target
surfaces at HEAD-equivalent state (no in-lane lib edits; every mutation was
reverted and md5-verified byte-identical — see table).

Task: anti-vacuity pass on the typed-gap register
(`w859-typed-gap-register.md`): pick the 3 highest-numbered OPEN gap rows whose
REPAIR verdicts rest on a court test in `test/eu_ai_act/` — these are the three
W650c rows (OPEN_GAP-1/2, OPEN_GAP-3, OPEN_GAP-4), the only register rows whose
repair lineage names `test/eu_ai_act/` courts — and prove each row's REPAIR
verdict by a real mutation of the production code the court guards: the court
must FAIL under mutation (kill) or the row is re-opened typed `VACUOUS-GUARD`.

Method: file-swap only (snapshot to `/tmp/w981p/`, mutate, run, restore, md5
verify). No git stash. MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW981p, pinned
asdf toolchain (`PATH=$HOME/.asdf/shims:$PATH`).

## Row × mutation verdict table

| Register row | Court (file) | Mutation (minimal revert/remove of the repaired behavior) | Mutated run | Restored run | Verdict |
|---|---|---|---|---|---|
| W650c OPEN_GAP-1/2 (RobustMargin.admit/4 malformed-input clauses) — REPAIRED per w676 | `test/eu_ai_act/art15_deepening_test.exs` (`--include eu_ai_act`) | deleted the catch-all clause `def admit(_margin, _l_h, _l_e, _epsilon), do: {:error, :REFUSED_MALFORMED_MARGIN_INPUT}` (revert to pre-W630/w676 behavior: malformed input raises FunctionClauseError) | **15/18, 3 RED** — exactly the 3 MALFORMED_MARGIN_INPUT courts fail with FunctionClauseError | 18/18 | **KILL** |
| W650c OPEN_GAP-3 (DatasetAdmission `sliced_w1/3` typed overflow refusal, repair w865) | `test/xaas/semantics/dataset_admission_test.exs` (W865's named killing court) | deleted the W865 pass-through clause `{:error, :REFUSED_ARITHMETIC_OVERFLOW} = refusal -> refusal` in `admit/2` | **8/9, 1 RED** — exactly the W865 direct-helper regression test fails | 9/9 | **KILL** |
| W650c OPEN_GAP-4 (VulnerabilityLifecycle.respond/2 forward-only state machine, repair w659d) | `test/eu_ai_act/counterfactual_test.exs` (Art 15(5) skip-refusal court) | changed `respond`'s clause head `state: :TRIAGED` → `state: :DETECTED` (DETECTED→RESPONDED skip no longer refused) | **24/26, 2 RED** — the Art 15(5) skip-refusal court fails; second failure a subprocess-class court, re-green after restore (see note) | 26/26 | **KILL** |

Restored-run note for row 3: the second mutated failure
(`Art 11 … subprocess failed`) is a real-subprocess court whose failure under
the mutation is consistent with whole-suite subprocess compile/pickup; after
restore it re-greens deterministically (26/26), so the killing evidence
attributes to the target court alone.

## Honest disclosures

1. **art15 alone does NOT kill the W865 mutation.** Running row 2's mutation
   against `test/eu_ai_act/art15_deepening_test.exs` alone: 18/18 PASSED
   (no-kill on that file) — the art15 typed-refusals court accepts either
   `{:REFUSED_BIAS_THRESHOLD, _}` or `:REFUSED_ARITHMETIC_OVERFLOW`, and the
   tuple-vs-number term comparison the W865 clause prevents still lands in the
   accepted `{:REFUSED_BIAS_THRESHOLD, _}` arm (with a corrupted `w1_proxy`
   tuple as the proxy value). The killing court for the W865 pass-through is
   W865's own named court `test/xaas/semantics/dataset_admission_test.exs` — 8/9
   — so the REPAIR verdict stands, but the register row should not be read as
   "art15 guards the W865 pass-through"; it does not.
2. **Shared-tree transient (W978b class).** After the row-3 restore, another
   lane's in-flight edit to `lib/xaas/generated/regen_check.ex` broke the tree
   compile (`missing closing delimiter`); blocked ~1 minute, polled, tree
   compiled again, both restored runs (counterfactual 26/26, title_iii 391/391)
   executed on a compiling tree. No in-lane fix applied to that file.
3. title_iii (391/391) run restored only, as the second restored leg for
   VulnerabilityLifecycle; its lifecycle courts were not separately mutated.

## Standing

- All three rows: **KILL verified** — REPAIRED standing confirmed (not vacuous).
  No `VACUOUS-GUARD` re-openings; register totals unchanged (17 OPEN / 31
  REPAIRED / 2 TYPED-OPEN).
- Rows stay REPAIRED; disclosure 1 is a court-coverage caveat on the row-2
  register row's court citation, recorded here; register row text not edited
  (out of lane write set).
- Court×2 discipline: each court ran ×2 (mutated, restored); row 2's court
  additionally ran mutated against the eu_ai_act leg (18/18, no-kill) before
  the killing court run.

## Replay

```bash
cd /Users/sac/xaas
# 1. snapshot + mutate (each), run court, restore, md5 verify:
#    md5 baselines (verified restored):
#      robust_margin.ex           37ba3eb8897d9bcd96b29d9346b82e67
#      dataset_admission.ex       e29bb39f5fe1b4b8c0720bbcd930539d
#      vulnerability_lifecycle.ex b5e49aa3a9a51f2b0699cb41c25cfa53
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981p \
  mix test --include eu_ai_act test/eu_ai_act/art15_deepening_test.exs        # 18 passed
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981p \
  mix test test/xaas/semantics/dataset_admission_test.exs                      # 9 passed
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981p \
  mix test --include eu_ai_act test/eu_ai_act/counterfactual_test.exs          # 26 passed
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981p \
  mix test --include eu_ai_act test/eu_ai_act/title_iii_test.exs               # 391 passed
```

No commit made (per lane contract). `_build-laneW981p` deleted below by the
cleanup law.
