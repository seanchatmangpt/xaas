# W984lz — evidence-index rows 93–95 (batch #12) probe

Date: 2026-10-08 · Lane: W984lz · Branch: `feat/playwright-surface` ·
NO commit, NO stash, NO branch switch, NO build root. Docs-only.

## Subject

Owed evidence-index rows flagged by W984lt (`w984lt-probe.md`) and
W984lx (`w984lx-probe.md`): rows 93–95 of
`docs/cro/artifacts/evidence-claims-index.md` for W984kn batch #12
(`fcef478b` / `6ff734f2` / `1ba31a97`), plus header stamp and
cumulative total.

## Real commands (from /Users/sac/xaas)

- `git log --oneline -3` → `1ba31a97`, `6ff734f2`, `fcef478b` (HEAD
  unchanged since W984lt/lx; no batch #13 at write time).
- `grep -rl 'fcef478b\|6ff734f2\|1ba31a97'
  docs/sjira/v26.10.6/plans docs/sjira/v26.10.7/plans` →
  `w984kn-commit.md` (carries 1ba31a97, cites the other two SHAs in its
  Commits table), plus `w984lt-probe.md` / `w984lx-probe.md` as
  independent HEAD-subject citations. 3/3 SHAs receipt-cited or
  self-carried.
- `grep w984lo docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md` → batch #13
  NOT landed (zero `w984lo*` files in either plans tree; only negative
  runbook mentions). No rows owed beyond 93–95 at write time.
- `w984kn-commit.md` read in full: batch gate **58 passed, 0 failures,
  exit 0** (10 candidate court files; sum of per-lane counts
  2+6+9+6+8+5+3+11+3+5); mock gate `[]` exit 0; disclosed 14-file
  pre-landing by `caf91669`; PromEx `:nxdomain` compile warning.
- `git diff --stat docs/cro/artifacts/evidence-claims-index.md` →
  98 insertions / 3 deletions on top of the already-uncommitted W984lg
  refresh (rows 77–92 are working-tree edits from that lane, not yet
  committed — disclosed, not touched by this lane).

## Diff

One file modified:
`docs/cro/artifacts/evidence-claims-index.md` — header stamp (+W984lz,
head `1ba31a97`), rows 93–95 appended after row 92, DRIFT summary
(W984lz) + Counts (W984lz) sections appended at end (final cumulative
total: **95 rows**). Prior rows and prior refresh sections untouched.
One file created: this receipt.

## Row-to-evidence mapping

| Row | SHA | Receipt | Grade |
|---|---|---|---|
| 93 | `fcef478b` | `docs/sjira/v26.10.7/plans/w984kn-commit.md` | witnessed (58/0 batch gate) |
| 94 | `6ff734f2` | same | grep (docs-only) |
| 95 | `1ba31a97` | same (self-carried; lt/lx as HEAD witnesses) | grep (receipt-carrier) |

## Gates

- Docs-only. No MIX_BUILD_ROOT; nothing owed. Mock gate not owed (no
  test files touched).
- No commit — coordinator owns landing.

## Standing

ALIVE (docs): rows 93–95 + stamp + totals on disk at HEAD `1ba31a97`,
working tree only. Replay = `git diff
docs/cro/artifacts/evidence-claims-index.md` (W984lz hunks only) + this
receipt.
