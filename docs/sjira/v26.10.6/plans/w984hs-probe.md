# W984hs — probe receipt (2026-10-07)

Lane: W984hs on the shared canonical checkout `/Users/sac/xaas`, branch
`feat/playwright-surface` (no branch switch, no commit, no stash; docs-only, no
build root).

## Part 1 — w984gm receipt-existence reconciliation

W984gy committed `w984gm-census-witness.md` in `56615dc3`; W984hg later
reported the file "does not exist on disk".

Commands run (real output):

- `git log --all --oneline -- "*w984gm*"` → single hit: `56615dc3`.
- `git ls-files "*w984gm*"` →
  `docs/sjira/v26.10.7/plans/w984gm-census-witness.md` (tracked, on disk).
- `git status --short | grep w984gm` → empty (not deleted, not modified).
- `diff <(git show 56615dc3:...) <disk>` → `IDENTICAL`.
- Content check: census line `1388 passed, 1 excluded`, HEAD line
  `102c178294297764ddbe32eeb72104dff50a3bbd`, verdict line
  "MEETS FLOOR: 1388 passed >= 1388 floor, 0 failed, 1 excluded".

**Verdict: false alarm.** The file exists and never left. W984hg evidently
looked under `docs/sjira/v26.10.6/plans/` while the file lives under
`docs/sjira/v26.10.7/plans/` (committed there in `56615dc3`). No restore was
performed — the on-disk copy is byte-identical to the commit.

## Part 2 — runbook landing addendum #4

Appended the fourth dated addendum to
`docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md` (W984ef/ft/gn conventions,
append-only; siblings concurrent). Contents, all re-read from real commands at
addendum time:

- HEAD at addendum: `009bd05768794cb8b62e7bc3fda0d9c81faad657` — no commits
  newer than `009bd057` (verified `git log --oneline -20`).
- Full table `ba3309c7` → `009bd057` (batches #6/#7): `ba3309c7`, `226803b8`,
  `3b0bf56d`, `56615dc3`, `857ebe60`, `d1a2b91b`, `69c5a095`, `3674159f`,
  `009bd057` — each via `git show --stat` + `grep -rl <sha> docs/sjira/`.
- Receipt grep results: batch commits cited by `w984gy-commit.md` and/or
  `w984hg-commit.md`; `857ebe60` and `009bd057` (and `3674159f` pre-`009bd057`)
  are self-carried with zero third-party citations.
- Open items from disk: W984hm batch #8 in flight (zero receipt hits);
  W984hd ash_pplan re-pin landed-in-ash_pplan (`w984hd-repin.md` present,
  receipt-only here); W984gm false alarm recorded; remaining blockers = merge
  of `feat/playwright-surface` to `main` + ash_pplan tag decision.

## Falsifier

`git ls-files "*w984gm*"` returning empty, or the on-disk w984gm content
diverging from `git show 56615dc3:docs/sjira/v26.10.7/plans/w984gm-census-witness.md`.

## Standing

LANDED (uncommitted, per lane contract — coordinator owns the commit).
No commit made; no build root created.
