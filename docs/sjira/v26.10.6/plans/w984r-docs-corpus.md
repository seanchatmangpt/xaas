# W984r — Docs-corpus integration commits

Date: 2026-10-07. Branch `feat/playwright-surface` (no push). Two atomic commits +
this receipt, all explicit-pathspec (`git commit -F <file> -- <paths>`), per W982b rule.

## Commit 1 — `5e21e87c` (14 files, +510/−2)

AIRo/CRO corpus:
- `docs/airo/` — `pin_drift_check.exs`, `pin-court-vocab.md`, 9 sibling-repo `airo-reference.md` dirs
  (ash_atlassian, ash_autofde, ash_dspy, ash_expo, ash_graphlaw, ash_kudzu, ash_planning_center,
  chatman-ecosystem, ggen-ecosystem). Owners W981e/f/j/w/m/h/2n/2q/2v/2w/3k — all done (receipts in corpus).
- `docs/cro/artifacts/airo-wiring-ledger.md` (+w982m xaas row, 6 fleet-SHA tables), `docs/cro/CYCLE-LOG.md`, `docs/cro/ARTIFACT-MANIFEST.md`.

Pre-staging checks (real output):
- Ledger consistency: typed-gap register `w859-typed-gap-register.md` has 51 data rows
  (53 `|` lines − header/separator) — matches CYCLE-LOG's "17 OPEN / 32 REPAIRED / 2 TYPED-OPEN = 51 rows".
  Ledger diff adds the w982m xaas row + fleet tables (beam4pm SHA update `6e4…`→`6e9…`).
- Mock gate on `docs/airo`:
  `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["docs/airo"]))'` → `[]` (clean;
  `pin_drift_check.exs` is a standalone script, not a test).

## Commit 2 — `8abb03be` (142 files, +10,752/−10)

- `docs/claude/diataxis/reference/actuation-and-semantics.md` (+62; owners W981m/W982v/W982l/W984m done)
  and `http-api-surface.md` (+130; W984m/W982l done).
- 138 untracked DONE-lane receipt `.md` files under `docs/sjira/v26.10.6/plans/` (w439…w984s series),
  enumerated fresh via `git ls-files --others` immediately before staging.

## Inclusions / exclusions

- Included per contract "receipt exists ⇒ lane finished": all enumerated untracked receipts,
  including w982l/t/d, w983c/d/e/g/i/k/j/n/p, w984b/e/j/m/n/o.
- `w983o` has no receipt on disk — nothing staged for it.
- **Disclosed sweep**: `w984s-o1-correction.md` was created by lane W984s between my enumeration
  (137 files) and staging; it landed in commit 2 (142 files). Per the receipt-exists contract its
  inclusion stands; content untouched.
- Excluded: `w969d-commit-msg.txt` (not a receipt); modified registers `w859`/`w891`/`w919`
  (left unstaged for their owners — still ` M` in worktree); my own receipt (below).
- Not touched: all `lib/`, `test/`, `.github` modifications from other lanes remain in worktree.

## Standing

- Docs corpus (AIRo/CRO + diataxis references + receipt backlog): LANDED — ALIVE at
  `5e21e87c` and `8abb03be`, observed execution (real `git commit` output above). No push.
- Gates: docs-only, no compile required; mock gate run on the only `.exs` staged → clean.
- Residual: w984r receipt itself uncommitted at write time; coordinator may fold or a
  follow-up pathspec commit may land it.
