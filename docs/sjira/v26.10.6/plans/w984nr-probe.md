# W984nr — evidence-claims-index refresh (batch #15)

Lane: W984nr · Branch: `feat/playwright-surface` · Subject: canonical checkout `/Users/sac/xaas`
Base: `7593a062` (W984nd batch #15 head; origin == HEAD verified by rev-parse) · Date: 2026-10-08

## Scope

Docs-only extension of `docs/cro/artifacts/evidence-claims-index.md`:
rows 110–115 for the W984nd landing batch #15 commits
(`4d96b097` `2e77ce47` `7904b088` `df22abb6` `17ef4b54` `7593a062`),
per-SHA receipts re-read from `docs/sjira/v26.10.7/plans/w984nd-commit.md`;
header refresh-list + head stamp updated; DRIFT summary (W984nr) and
Counts (W984nr) sections appended. No commit made (lane directive:
docs-only, no commit).

## Evidence commands (real output)

- `git log --oneline -15` → head `7593a062`; 6 batch-#15 SHAs above `20a24db0`.
- `git rev-parse origin/feat/playwright-surface HEAD` → both `7593a062…`.
- Per-commit `git show --stat` ×6 — diffs match receipt claims (file lists
  and line counts cross-checked against `w984nd-commit.md` §Commits).
- On-disk spot-checks: `grep -c oxigraph lib/xaas/generated/regen_check.ex`
  → 4; bare-atom pins present in both execution_fabric test files;
  EVIDENCED flip present in `lib/xaas/semantics/oversight_governance.ex`;
  `pack_gate_engine_court_w984md_test.exs`, `pack_queries_court_w984le_test.exs`,
  `census_tail_court_w984mm_test.exs`, `e2e/README.md` all present.
- Blocker-1 re-check: `git merge-base --is-ancestor 56325fa5 origin/main`
  → exit 1 (unchanged from W984ng).
- Row count after edit: 115 table rows (109 → 115).

## Grades

witnessed 5 (#110–114), grep 1 (#115, receipt-carrier). No divergence
found between receipt and commit claims. Disclosures recorded: w984dg
court EXCLUDED (RED 4/22 per coordinator, `w650h16-commit.md`);
in-flight mj/mr/mt/na + mf-family `priv/ash_surface/*` not landed;
cleanup-plan.json / emergency-reclaim-receipt.json /
priv/semantic/generated/ coordinator triage.

## Standing

LANDED (docs). Cumulative index: 115 rows at head `7593a062`.
No build root created; no commit.
