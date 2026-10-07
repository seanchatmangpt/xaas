# W975 — Castle refusal-negative coverage fold (lane receipt)

- **Date**: 2026-10-07
- **Lane**: W975 (v26.10.6 campaign), branch `feat/playwright-surface`
- **Task**: fold the W863+W974 castle refusal-negative repair into the campaign record.
- **Subject**: tree state at run time (branch `feat/playwright-surface`, uncommitted
  working tree, HEAD `fab56ae1`).

## Actions

1. Wrote `docs/cro/artifacts/castle-refusal-negative-coverage.md` (facts only, ≤20
   lines of substance): 5 refusal classes, court files, real pass counts, receipts
   w828/w863/w974.
2. Ran both files once each, real tails:
   - `mix test test/xaas/castle_execute_court_test.exs` → `Result: 10 passed` (128.1s)
   - `mix test test/xaas/castle_refusal_negative_test.exs` → `Result: 19 passed` (4.2s, post-W974)
3. W974 receipt was not on disk at either check (start and post-run retry); its
   fix is witnessed by the refusal-negative file's clean 19/19 post-W974 run.

## Blockers encountered and cleared (transcription-level, disclosed)

Two tree-wide compile blockers from concurrent lanes' in-flight files, both fixed
minimally to unblock compilation; content-intent unchanged:

- `lib/xaas/operations/capability_liveness_regressions.ex`: duplicated trailing
  `end end` after module close — removed the two stray lines.
- `lib/xaas/governance/checks/freeze_window_active.ex` (untracked, other lane's
  new file): missing `require Ash.Query` — added the require. Owning lane should
  re-verify on their next run.

## Standing

- Court file `castle_execute_court_test.exs` 10/10: **ALIVE**
- Refusal-negative file post-W974 19/19: **ALIVE**
- W974 receipt file: not present at lane time (UNKNOWN, not evidence of absence)
- `:castle_kernel` court with real CASTLE binary: not run (carried exclusion from w828/w863)

## Replay

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/castle_execute_court_test.exs
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/castle_refusal_negative_test.exs
```
