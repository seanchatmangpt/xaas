# OP Branch Landing Decisions — push/PR/merge calls for wave fix branches (operator act)

## Summary

No agent pushed, merged, or PR'd anything (per the consequence fence: push /
open PR / merge are DO-list operations requiring a fresh operator cut). Five
local branches now hold qualified, test-backed work with nowhere to go until
the operator decides land-vs-defer for each.

## Status

BLOCKED — awaiting operator decisions (per-branch land/PR/defer).

## Scope

Decision table (evidence in each named receipt):

| Branch | Repo | Tip | Content | Court evidence |
|---|---|---|---|---|
| `fix/ggen-v26.9.17-boundary` | ggen | `5cc8808c1` (5 commits) | fmt, pack/consumer reconciliation, packCount, ratchet, rmcp proof restoration | `just pre-commit` exit 0, 17 gates |
| `fix/affidavit-v26.9.17-boundary` | affidavit | `3106f64` (3 commits) | fmt sweep, §6 stderr contract, witness flags | 352 tests green; see D4 ticket before landing |
| `fix/autofde-lab-v26.9.17-boundary` | autofde-lab | `156cb6fe` (2 commits) | ocel_tracer typed-attrs fix + release_tag wiring | 11/12 gates; tag → 12/12 |
| `feat/ep2-replay-contract` | autofde-lab | `112d7e41` | Episode₂ replay contract, 811 insertions | 47 tests; see integration ticket |
| `feat/v26.9.17-release-affidavit` | affidavit (worktree) | patch block uncommitted | issuance worktree variant | see `affidavit-buildability-d4.md` |

Also pending: `feat/ep1-missed-epoch-receipt` (already pushed to origin by an
earlier pass, 10 commits, 0 behind origin/main) — decide PR.

1. Operator: per branch, open PR / merge / explicitly defer.
2. Agent slice: after each decision, prepare the PR description from the
   receipt (commands + exits), never push unilaterally.

## Key Invariant(s)

- Agents never push/merge; every landing is an operator cut.
- A merge is not complete until code AND documentation are checked
  (receipts reference docs to update: PROGRESS.md, RELEASE-STATE).

## Relationship to Existing Work

- `RELEASE-STATE-v26.9.17.md` operator act list item 6; `ledger-closure.md`
  (xaas commits already landed locally on `feat/execution-actuation-fabric`:
  `32b5ba1`, `113a6eb`, `6ff1a32` — same decision applies to that branch's
  eventual PR).

## Falsifiers / What Would Defeat This

- A branch lands without its court evidence linked in the PR.
- `feat/ep2-replay-contract` merges into the tagged release AFTER the tag
  (fence/tag drift — tag would need recutting).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | see table | all tips court-witnessed | per-branch operator decisions |
