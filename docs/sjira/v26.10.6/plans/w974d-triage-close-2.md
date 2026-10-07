# W974d — Triage close (final) receipt

- **Lane**: W974d, xaas v26.10.6 campaign, 2026-10-07.
- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` head `fab56ae1` (worktree
  dirty from concurrent lanes; this lane appended only to the two named docs files,
  no commit per lane contract).
- **Task**: reconcile the concurrent W971b / W971c triage-close footers into one
  authoritative final-close footer on `docs/sjira/v26.10.6/plans/w891-gap-triage.md`.

## O / O*

- O: W971b receipt (`w971b-triage-close.md`: CLOSED, 17/31/2 on 50 rows), W971c
  footer (`w971c-triage-progress-fold.md` fold in w891: 9/10 top-10 REPAIRED,
  W804 OPERATOR open), register `w859-typed-gap-register.md` on disk.
- O*: both priors re-read from disk this session; register totals re-derived by
  grep, not taken from either footer.

## μ / diff

- Appended "Final close (W974d, 2026-10-07)" footer to
  `docs/sjira/v26.10.6/plans/w891-gap-triage.md` (handwritten prose only; no
  generated surfaces, no register edits, no code).
- Added `— SUPERSEDED by the W974d final-close footer below` markers to both
  prior footer headings (W971b, W971c) in the same file, matching the file's
  existing supersede convention (cf. the W914 footer's marker).

## Footer content (all facts file-derived, re-verified this session)

1. **Definitive totals**: `grep -oE '\| (OPEN|REPAIRED|TYPED-OPEN) \|'
   w859-typed-gap-register.md | sort | uniq -c` → 17 OPEN / 31 REPAIRED /
   2 TYPED-OPEN = 50 rows. Confirms W971b's figure; supersedes all interim
   counts in the triage file.
2. **CHEAP-REPAIR**: all 15 closed — w897 / w900 / w902 receipts + follow-ups
   w928, w945c; verify-first closures on HEAD via W746, W792, W818 (+w902 for
   the remaining 2 of the W793 4-gap row), W852; flips witnessed by
   w968b-register-final-flips.md.
3. **DESIGN**: 18 rows spec'd in w905-design-gap-specs.md; waves 1-3
   (w968c / w969b / w969c) dispatched but receipts NOT on disk (re-verified by
   this lane's `ls`, independently of W971b's check) → wave standing UNKNOWN.
   W971c's "in flight" retained as dispatch status only.
4. **OPERATOR (2)**: W804 (direct-DDL index, unstamped schema_migrations, replay
   hazard per register L50 W971 audit annotation; stamp or drop-and-replay —
   coordinator) and W902 (xaas_test contamination; hygiene pass or per-lane
   test DBs). Both stay OPEN.
5. **Sole typed open gap**: 49.3 (EU-AI-Act Title IV deployer EU-database
   registration OPEN_GAP); W811 test-scope boundary is the other TYPED-OPEN
   slot (scope disclosure, not a defect). W784 TOFU remains backlog-deferred in
   the OPEN count; promote recommendation not acted on.
6. **Reconciliation verdict**: W971b and W971c are complements, not conflicts —
   W971b's totals figure confirmed correct; W971c's top-10 disposition confirmed
   correct and folded. The W974d footer is the single closing authority.

## Commands / exits (all exit 0)

- `grep -oE '\| (OPEN|REPAIRED|TYPED-OPEN) \|' w859-typed-gap-register.md | sort | uniq -c`
  → 17/31/2 (twice: at intake and at close; unchanged).
- `ls w968c-* w969b-* w969c-*` in plans dir → no matches (wave receipts absent).
- `tail` reads of w971b-triage-close.md, w971c fold, w897/w902 receipts for
  citation accuracy.
- Heredoc append to w891-gap-triage.md → exit 0, tail re-read confirms footer
  is last content in file; two Edit ops added supersede markers (confirmed).

## Verification ladder

Narrow (on-disk greps + ls) → file append + re-read confirmation. Documentation-
only lane: no build, no tests, no build root, no commit — no court required.

## Standing

- Triage standing: **CLOSED (final)** — W974d footer is authoritative; both
  prior footers marked superseded.
- Register: PARTIAL_ALIVE (17 OPEN / 31 REPAIRED / 2 TYPED-OPEN, grep-verified).
- Waves 1-3: UNKNOWN (receipts not landed).
- Receipt: this file. Replay = re-run the status grep on w859, `ls` the wave
  receipt globs, and read the final footer tail of w891-gap-triage.md.

## Falsifiers

- F1: status grep on w859 returning totals ≠ 17/31/2 → this footer stale.
- F2: `ls docs/sjira/v26.10.6/plans/w968c-*.md w969b-*.md w969c-*.md` matching
  any file → "receipts not landed" claim invalid; footer under-reports wave
  standing and must be amended.
- F3: a later footer in w891-gap-triage.md lacking a supersede pointer to this
  one → W974d is no longer the closing authority.
