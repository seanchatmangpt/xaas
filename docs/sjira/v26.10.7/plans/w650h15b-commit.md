# W650h15b — W650y3/W984dp3 duplicate-court collision + landing receipt

Date: 2026-10-07. Lane W650h15b, v26.10.7 fleet seal. Repo /Users/sac/xaas,
branch feat/playwright-surface.

## Grounding (the flagged collision is REAL)

W650h14b's truth table flagged `w650y3_atlassian_cursor_depth_court_test.exs`
as untracked-green with no receipt. Grounding confirmed **two distinct files**
covering the SAME module (`Xaas.Sjira.AtlassianCursor`) with the SAME
invariant classes:

| | w650y3_atlassian_cursor_depth_court_test.exs | w984dp3_atlassian_cursor_court_test.exs |
|---|---|---|
| git state | untracked, no receipt (per W650h14b + W650g3) | tracked, commit 9ec12305, receipt `docs/sjira/v26.10.6/plans/w984dp3-sjira.md` |
| module | `Xaas.Sjira.W650y3AtlassianCursorDepthCourtTest` | `Xaas.Sjira.W984dp3AtlassianCursorCourtTest` |
| invariants | exhausted typed refusal (`:cursor_exhausted`), termination precedence total>isLast>shortfall, seen accumulation, token-mode params/exhaustion, empty-page boundary | identical invariant set: exhausted typed refusal, precedence (total wins over isLast in BOTH directions), shortfall, seen accumulation + params roundtrip, token mode |

Both files carry per-test mutation-kill rationale targeting the same cond
reordering / clause-deletion mutant classes. This is a duplicate-court
collision (two lanes independently depth-courted the same module), not
complementary coverage. The only deltas in W650y3 (empty-page
`max(length,1)` termination, seen-across-modes) are sub-cases of the same
termination/accounting predicates W984dp3 already kills mutants for.

## Resolution (per dispatch rule)

Dropped the older-filer unreceipted duplicate: `rm
test/xaas/sjira/w650y3_atlassian_cursor_depth_court_test.exs` (was untracked,
so no `git rm` needed). Survivor W984dp3 stays landed as-is — no new test
file enters the tree from this lane.

## Gate (real execution, lane build root `_build-laneW650h15b`)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650h15b mix compile --force` → EXIT=0
  (pre-existing warnings only, e.g. `lib/xaas/operations/refusal_ledger_export.ex:388`; no errors)
- `mix test test/xaas/sjira/w984dp3_atlassian_cursor_court_test.exs` → **5 passed**, EXIT=0, 0.05s

## Standing

- W650y3 duplicate-court defect: RESOLVED (file dropped, survivor receipted
  and green ×1 on this lane's fresh compile).
- W650y3 missing-receipt defect: RESOLVED-BY-DROP (no artifact landed ⇒ no
  receipt owed; this document is the landing record).
- Falsifier for this resolution: if `w650y3_atlassian_cursor_depth_court_test.exs`
  reappears in the tree, the collision resolution was not respected.
