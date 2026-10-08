# W984nx — landing addendum #25 probe receipt (2026-10-08)

- **Subject**: branch `feat/playwright-surface`, HEAD = `7593a062` =
  origin `7593a062bf6c350b56df4987c9e5847f0a1223e6` (verified at write;
  `git log 7593a062..HEAD` → 0 rows). No batch #16 landed.
- **O**: `git log --oneline -15`, `git rev-parse HEAD origin/...`,
  per-disk re-counts (manifest 92 rows, evidence index 115 rows,
  untracked docs/sjira porcelain = 23, `_build-lane*` = 7 roots
  ke/kh/ma/mi/mw/np/nu), probe existence checks (np/nu absent →
  in-flight; mt court file UNTRACKED).
- **O\***: all counts re-read from disk this lane, not recalled.
- **μ/diff**: append-only ~70-line section to
  `docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md` (W984ef→nv heading
  conventions); no other file touched; no edits above own block.
- **Generated vs handwritten**: handwritten docs-only lane.
- **Commands/exits**: append via heredoc `cat >>` (exit 0); count greps
  (exit 0); probe `ls` checks (2 expected ENOENT for np/nu = disclosed
  in-flight signal).
- **Verification**: `git diff --stat` on runbook = 476 insertions
  (pre-existing through nv + this section); append-only confirmed.
- **Replay**: re-run the count greps and `git rev-parse` listed above at
  any later SHA; the addendum text is self-contained in the runbook.
- **Standing**: self-carried, docs-only, NO commit, no build root.
- **Falsifiers**: none new; blockers unchanged (coordinator merge of
  `feat/playwright-surface` to `main` + operator ash_pplan call).
