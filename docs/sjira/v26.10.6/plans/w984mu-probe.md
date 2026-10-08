# W984mu — Landing Addendum #17 Probe (docs-only, no commit)

Lane: W984mu · Date: 2026-10-08 · Branch `feat/playwright-surface` (no branch
switch, no commit, no stash, no build root). Task: append the seventeenth dated
landing addendum to `docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md` per the
W984ef→ms conventions.

## Commands (real output)

```bash
git log --oneline -20          # HEAD 567ab1f5, no new commits since W984ms
git fetch origin feat/playwright-surface
git rev-parse HEAD origin/feat/playwright-surface
# 567ab1f509cf2fa38e4e8d105748b5b38bb2bde4 (both) — origin == HEAD, nothing to push
ls docs/sjira/v26.10.6/plans/ docs/sjira/v26.10.7/plans/ | grep -E 'w984m|w984n'
grep -cE '^\| *[0-9]+ ' docs/cro/artifacts/evidence-claims-index.md   # 102
git status --porcelain docs/sjira | grep '^??' | wc -l                 # 81
grep -c '^| 2[1-9] ' docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md           # 9
grep -n "3792" docs/sjira/v26.10.7/plans/w984km-wave-receipt.md        # :207
```

## Open-item deltas vs W984ms (all read from disk)

- **Zero new commits; no batch #14.** W984mo in flight (root
  `_build-laneW984mo`, no receipt file, no commit).
- `w984mi-census-witness.md` NOW ON DISK (v26.10.7 tree): 1394/0/1 @
  `567ab1f5`, exit 0, floor HELD; disclosed denied build-root cleanup →
  `_build-laneW984mi` lease remains.
- `w984mb-probe.md` NOW ON DISK (v26.10.6 tree): Mutation Audit #9, M1–M5
  KILLED, M6 survived-single/killed-as-compound; own cleanup SUCCEEDED
  (lane roots 10 → 9).
- `w984n-ashsurface-regen-check.md` NOW DISCLOSED (v26.10.6 tree; predates
  W984ms but outside its grep scope): PARTIAL_ALIVE, bytes STALE (+0
  entrypoints, SPEC-07 org_id missing from 4 zod schemas); subject skew —
  cites xaas HEAD `1f2a2b23`, not current `567ab1f5`.
- Still ABSENT: `w984mt*` (ranker vacuous-fallback court, in flight, no
  root observed), `w984mj*`, `w984mr*` (in flight, roots present),
  `w984mk*` (fixture regen), `w984mo*` (batch #14).
- Unchanged: wave total 3792 (w984mp), closure rows 21–29 (w984mq, 9
  re-counted), me audit #10, evidence index 102, 2 blockers DRAFT.
- Lane roots `_build-lane*`: 9 (DOWN from 10; `W984mb` self-removed;
  `W984mi` newly lease-held per its denied cleanup).

## Verification

- `git diff` on the runbook shows only append-only addendum sections
  (mh/ml/ms pre-existing uncommitted + this lane's mu section, appended
  last, lines 1055+). No other file touched by this lane.
- Docs-only; no commit; no build root created; nothing to clean.
