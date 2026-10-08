# W984jl — runbook convention append (mutation-audit methodology fix-forward)

- Lane: W984jl, canonical checkout /Users/sac/xaas, branch feat/playwright-surface.
  Docs-only: no commit, no build root, no stash.
- Task: fix forward the two W984ha findings (compound-mutation leg; tag-exclusion
  false green) into the runbook conventions, cross-referencing W984ig.

## Verify-on-disk first

- Read `docs/sjira/v26.10.6/plans/w984ha-probe.md`: confirms M3 single-clamp
  mutants SURVIVED ×2 while compound mutant M3c was KILLED
  (lib/xaas/sjira/rate_limit.ex lines 27+52, redundant clamp pair), and that
  eu_ai_act courts report "0 tests, N excluded, exit 0" under bare `mix test`
  (green lie) requiring `--include eu_ai_act`.
- Read `docs/sjira/v26.10.6/plans/w984ig-quiescent-repair.md`: confirms the same
  tag-exclusion hazard hid the stale `quiescent_stop_deepening_test.exs:203`
  `:OPEN_GAP` assertion (lib is all-`:EVIDENCED` post-W984eb) for a whole
  campaign leg; 7 tests excluded, exit 0, two consistent baseline runs.

## Edit (1 file, append-only)

`docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md` — appended to the Conventions
section (after the classifier-revision paragraph, before the W984ef landing
addendum) a "Mutation-probe conventions (from the 2026-10-07 mutation-audit
series)" block with two bullets:

1. Compound-mutation leg required for redundant-pair guards; single-mutant
   survival ≠ vacuity. Cites `plans/w984ha-probe.md`.
2. Tag-excluded courts ("0 tests, N excluded, exit 0") under bare `mix test`
   are FALSE GREENS; mutation/court verification must pass `--include <tag>`;
   cross-references the W984ig stale-assertion leg. Cites both receipts.

## Verification

- Re-read of the edited section on disk confirms the block landed intact with
  both receipt paths cited (Edit tool success + section re-read).
- No commands gated on compile/tests: docs-only lane.

## Cleanup

- No build root created. No commit (per lane contract).
