# W650g4 — Receipt-Presence Discrepancy Court

Lane W650g4, v26.10.7 fleet seal. Repo `/Users/sac/xaas`, branch
`feat/playwright-surface`, HEAD at court time `ccddec4e`. Read-only lane;
only this receipt written. Nothing staged or committed.

## Finding

W650g3's claim is **FALSE** for w984dj2-spg-gate.md and **TRUE-but-expected**
for w650f2-c0-flip.md.

W650g3 (`docs/sjira/v26.10.7/plans/w650g3-commit.md:19`) states
"`docs/sjira/v26.10.7/plans/w984dj2-spg-gate.md` — **does not exist on disk and
is not tracked**. Not untracked; absent." W650g3 checked the wrong directory:
the file lives in `docs/sjira/v26.10.6/plans/`, not `v26.10.7/plans/`. The
file exists on disk, is tracked in git, and carries W984dj2's owner receipt
plus W650x's appended adjudication section (line 113:
"## Follow-up adjudication (appended by lane W650x, 2026-10-07)").

## Per-file truth table (commands run 2026-10-07, HEAD ccddec4e)

| path | ls -la | git status | git log --all | verdict |
|---|---|---|---|---|
| `docs/sjira/v26.10.6/plans/w984dj2-spg-gate.md` | present, 7492 bytes, mtime Oct 7 15:25 | ` M` (modified, tracked, unstaged) | landed in `50638a5e` (W650h2 receipts sweep 3) | **EXISTS — W650g3's "does not exist at all" is refuted** |
| `docs/sjira/v26.10.6/plans/w650f2-c0-flip.md` | absent | n/a | absent (also no match under v26.10.7/plans, no --follow hits) | absent — expected; W650f2 still running, owner receipt not yet written |
| `test/xaas/actuation/spg_gate_test.exs` | present, 5368 bytes, mtime Oct 7 14:52 | clean | committed in `a5f81439` (W650g2 restage) | tracked and landed, as W650g2 claimed |

## Diagnosis of W650g3's miss

W650g3's own receipt enumerates both stragglers with the
`docs/sjira/v26.10.7/plans/` prefix. W984dj2's actual artifact was written to
the v26.10.6 campaign directory (W984dj2 ran under v26.10.6). The v26.10.6
vs v26.10.7 plans-directory confusion — not an owner-lane failure — produced
the false "absent" verdict. Additional note: the working-tree copy of
w984dj2-spg-gate.md is locally modified relative to the committed version in
`50638a5e` (post-commit edits by later lanes), which is consistent with the
W650x append already present in both.

## Standing

- w984dj2-spg-gate.md receipt presence: **ALIVE** (disk + git, v26.10.6/plans).
- w650f2-c0-flip.md receipt presence: **BLOCKED (in flight)** — owner lane
  W650f2 still running; absent is expected, not a defect.
- test/xaas/actuation/spg_gate_test.exs: **ALIVE** at `a5f81439`.
- W650g3's "owner lane never wrote it" claim: **REFUTED** (wrong-directory
  check), with the correction recorded here.

## Falsifier

`ls docs/sjira/v26.10.6/plans/w984dj2-spg-gate.md` returning "No such file or
directory" would refute this receipt.
