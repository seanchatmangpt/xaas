# W984ct2b — Lane Receipt: W984ct Quiescent-Stop Race Work — Commit Landing

- **Subject**: branch `feat/playwright-surface`, commit `c5db9fd1aec700b54445de0b383502c181053709`
- **Authority**: coordinator-delegated commit for lane W984ct2b (explicit pathspec only, no push)
- **Task**: verify freshness of W984ct's landed-uncommitted work, rerun the gate on a fresh
  lane build root, stage exactly the lane's paths, commit, receipt.

## Freshness verification

- `lib/xaas/actuation/quiescent_stop.ex` mtime 12:51, `test/xaas/oversight/w984cf_oversight_depth_test.exs`
  mtime 12:37; verified stable ≥5 min at 12:59 (no writes since).
- Receipt `w984ct-quiescent-race.md` records no md5s (mid-lane corruption was
  `git checkout HEAD` + redone small Edits), so freshness was verified by content instead:
  on-disk file contains the `{:ok, %{status: :replayed}} -> {:ok, %{already_stopped: true}}`
  clause, both typed atoms `:REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT` /
  `:REFUSED_STOP_CLAIM_CONTENTION`, the `quiescent-stop:<resource>:<subject_id>` claim intent,
  and `release_claim/2` — matching the receipt's described final state exactly.
  Test file has 8 hits for `typed_stop_refusal?` / `crashes == []` / `length(receipts) == 1`
  and no live `CaseClauseError` allowance (only comments). **MATCH.**

## Gate (real, PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW984ct2b)

```
mix compile (fresh root, full dep build, ~20 min)                            → EXIT=0
mix test test/xaas/oversight/w984cf_oversight_depth_test.exs \
         test/xaas_web/quiescent_fabric_tie_test.exs \
         test/xaas/actuation/quiescent_stop_test.exs                         → 19 passed, EXIT=0
```

×1 as ordered. (A logged `[error]` idempotency_conflict line in the oversight test output is
expected race-court output, not a failure.) Prior lane evidence: 5 seeds total across the two
race courts + deepening in the original receipt `w984ct-quiescent-race.md`, standing ALIVE.

## Commit

- **SHA**: `c5db9fd1aec700b54445de0b383502c181053709` — parent `1c00d586`
- **Paths staged and committed (exactly 3, explicit pathspec)**:
  - `lib/xaas/actuation/quiescent_stop.ex`
  - `test/xaas/oversight/w984cf_oversight_depth_test.exs`
  - `docs/sjira/v26.10.6/plans/w984ct-quiescent-race.md`
- 3 files changed, 566 insertions. Other lanes' staged files were in the shared index;
  the pathspec commit did not sweep them (verified: `git show --stat c5db9fd1` = exactly 3 paths).
- Concurrency note: a disjoint lane commit `6222135e` (docs(sjira) receipts corpus) landed on
  top of `c5db9fd1` seconds later; files disjoint, no collision, no action taken.
- **No push** (per lane law).

## Transport failures / notes

- Fresh-root compile exceeded the 600 s foreground limit and ran in the background to
  completion (~20 min, full dep build); EXIT=0 confirmed from task output.
- Lane build root `_build-laneW984ct2b` (~430 MB) left on disk for the coordinator per the
  cleanup law (`rm -rf` not attempted).

## Standing

**ALIVE** — freshness verified, gate green on fresh root, commit landed with exact paths,
receipt written. Falsifier for this receipt: `git show --stat c5db9fd1` showing any path
beyond the three declared ones, or the gate files red at the committed subject.
