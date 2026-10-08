# W984nt — runbook landing addendum #23 (docs-only lane)

Lane: W984nt · Branch: `feat/playwright-surface` · Subject: canonical checkout
`/Users/sac/xaas` · Base: `7593a062` (= origin, verified by rev-parse) ·
Date: 2026-10-08

## Scope

Append-only twenty-third dated landing addendum to
`docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md` (section "Landing addendum —
2026-10-08 (lane W984nt)"), following the ef→ns conventions. No other file
edited; no commit; no build root.

## Evidence commands (real output)

- `git log --oneline -15` → head `7593a062`; `git log --oneline
  7593a062..HEAD` → 0 rows (no new commits since nq's coverage).
- `git rev-parse HEAD origin/feat/playwright-surface` → both
  `7593a062bf6c350b56df4987c9e5847f0a1223e6`.
- Evidence index row count: `grep -cE '^\| *[0-9]+ '
  docs/cro/artifacts/evidence-claims-index.md` → 115 (W984nr extension,
  rows 110–115).
- Commit manifest row count: same grep on `_COMMIT_MANIFEST.md` → 92
  (W984ns extension, rows 87–92); batch-#15-rows-owed item closed.
- Mutation audits on disk: `w984{kp,lc,mb,me,mj,mr,nf,ni}-probe.md`
  present; in-flight nl/np (no probes, both hold build roots).
- W984mt ranker court: `test/xaas/library/
  ranker_fallback_court_w984mt_test.exs` UNTRACKED in tree, receipt
  `w984mt-probe.md` UNTRACKED, not landed.
- Untracked `docs/sjira` porcelain entries: 18 (ns probe landed
  mid-census; 17 seen at first count).
- `_build-lane*` roots: 9 (ke/kh/ma/mi/mw/nj/nl/no/np); mt and ni
  cleared since nq's 10; np appeared.
- `git diff --stat` on the runbook at addendum time: 349 insertions
  (pre-existing uncommitted sections through nq + this nt section).

## Result

Addendum appended; open-items refresh recorded (evidence index 115,
manifest 92, mutation audits 8 on disk / 2 in-flight, mt court unlanded,
9 lane roots, 18 untracked docs, blockers unchanged: merge to main +
operator ash_pplan call). No commit, no build root, docs-only.
