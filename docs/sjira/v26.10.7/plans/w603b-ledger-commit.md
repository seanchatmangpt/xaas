# W603b — Authority ledger export commit receipt

Lane: W603b, v26.10.7 release campaign. Repo: /Users/sac/xaas (canonical
checkout, branch `feat/playwright-surface`). Coordinator-delegated commit
authority, no push.

## Subject

Commit `e27ea5c0cd1255b4a3209c9ce4dab0778913ab17`
(`feat/playwright-surface`, parent cf228da6), exactly 4 paths, 671 insertions:

- `lib/xaas/operations/authority_ledger_export.ex`
- `lib/mix/tasks/xaas.export_authority_ledger.ex`
- `test/xaas/operations/authority_ledger_export_test.exs`
- `docs/sjira/v26.10.7/plans/w603-authority-ledger.md` (upstream W603 receipt)

## Freshness gate

Re-stat'd at lane start (12:42:55) and after a 160 s wait (12:45:51): all
four mtimes unchanged; newest surface (test file, 12:40:12) stable ≥5 min at
gate run time. W984ci compile-freeze SLA unblock present in module
(authority_ledger_export.ex:34); W603 receipt's exclusions section intact.

## Gate (all EXIT=0, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW603b)

1. `mix compile --force` (fresh root): EXIT=0. Tail: `Generated xaas app /
   COMPILE_EXIT=0`. (Pre-existing warnings elsewhere in tree, e.g.
   refusal_ledger_export.ex:377, not session-introduced.)
2. Export court: `mix test test/xaas/operations/authority_ledger_export_test.exs`
   → `9 passed` in 0.7 s.
3. Real operator run: `mix xaas.export_authority_ledger --out
   /tmp/w603b-bundle.json` → typed success, EXIT=0, non-empty 8274-byte
   bundle, entries carry leaf_hash/authority/occurred_at
   (first entry: Xaas.Library.Curation create, succeeded).

## Commit mechanics disclosure (cross-lane incident, fixed forward)

`git commit -F` swept a **pre-staged** deletion of
`docs/sjira/v26.10.7/plans/w601b-tautology-commit.md` sitting in the shared
index from another lane (5 files, 43 deletions). Fixed forward without
disturbing history: `git checkout HEAD^ -- <path>` to restore the other
lane's exact content, `git commit --amend` → final `e27ea5c0` is exactly the
4 intended paths. The other lane's deletion intent is reverted in the working
tree/index by the restore; that lane must re-stage its deletion. No stash, no
reset --hard. Commit was never pushed, so amend was safe.

## Standing

- W603 implementation: ALIVE on exact subject `e27ea5c0` — compile, 9-test
  court, and real export CLI run all witnessed on this lane.
- W601b commit (w601b-tautology-commit.md content) still landed as untracked
  file restored; its own lane owns its commit.
- Residual: Grafana/PromEx upload warnings during CLI run are pre-existing
  offline-environment noise (nxdomain), unrelated.

## Lane cleanup

Deletion of `_build-laneW603b` was attempted and REFUSED by the session
permission system (rm -rf denied, twice). Left on disk for the coordinator
per the task's fallback ("else leave for coordinator"). Coordinator should
remove it at integration (lane-lease cleanup law).
