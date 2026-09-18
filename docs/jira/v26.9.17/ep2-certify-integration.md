# EP2 Certify Integration — reconcile the divergent autofde-lab branches

## Summary

The crown branch `fix/autofde-lab-v26.9.17-boundary` (`156cb6fe`: release_tag
wiring, 11/12) and the Episode₂ branch `feat/ep2-replay-contract`
(`112d7e41`: replay contract, 811 insertions, 47 tests) are DIVERGENT — both
forked from `64181bb7`. The release cannot honestly carry the replay
machinery until they are one history, and the tag decision
(`op-release-tag-cut.md`) explicitly excludes `112d7e41` today.

## Status

BLOCKED — on the operator's include-or-defer decision (see
`op-release-tag-cut.md` scope item 4).

## Scope

1. Operator decision: Episode₂ machinery IN v26.9.17 (integrate, then tag the
   merged tip) or DEFERRED to the next epoch (tag `156cb6fe` now; integrate
   after).
2. If IN: merge/rebase `112d7e41` onto the certify branch (conflicts expected
   around `conformance/runner.py` + `tests/sa2a/`), re-run the full court:
   the 12-gate runner + the 47 ep2 tests + the runner tripwires — all green
   from one tip.
3. If DEFERRED: record the defer decision in this ticket's History; the
   integration becomes a post-release follow-up with the same scope.
4. Receipt: merge/rebase commands + exit codes, unified court output, final
   tip SHA for the tag decision.

## Key Invariant(s)

- One tip must carry ALL release claims (no "12/12 on one branch, 47/47 on
  another" split evidence).
- No force-push; no history rewrite of either branch.

## Relationship to Existing Work

- `certify-prep.md` (branch A evidence) + `ep2-replay.md` (branch B
  evidence); `RELEASE-STATE-v26.9.17.md` notes the divergence.

## Falsifiers / What Would Defeat This

- Integrated tip passes neither branch's court (merge broke both) — must be
  repaired before any tag.
- Tag cut on a tip that is not the integration result (fence/tag drift).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | autofde-lab 156cb6fe ⊥ 112d7e41 (common base 64181bb7) | A: runner 11/12; B: 47 tests | operator IN/DEFER → integrate → unified court |
