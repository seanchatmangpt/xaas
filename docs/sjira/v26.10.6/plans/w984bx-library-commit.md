# W984bx — Library Integration Commit (W984ad fulfill-cap)

Date: 2026-10-07 · Branch: `feat/playwright-surface` · Standing: ALIVE (commit landed, not pushed)

## Subject
- Commit: `9068db79b45811c2972f52145f0c921c2c92bf73` (parent `755b6559` — W984bl receipt commit)
- Message: `fix(library): W984ad fulfill-cap borrow limit change + hold_request wiring + stress court flip (w984bx library integration)`

## Staged paths (exactly 3)
- `lib/xaas/library/changes/enforce_borrow_cap.ex` (new; content already identical in parent tree via W984bl landing — blob-equal, so diff-tree shows 2 paths)
- `lib/xaas/library/hold_request.ex` (48 +-: 33+/15-, W984ad diff)
- `test/xaas/library/checkout_hold_lifecycle_stress_test.exs` (new, 389 lines)

## Gates (MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW984bx, asdf elixir 1.20.2-otp-28)
1. Fresh-root `mix compile --strict --force` → EXIT=0
2. `mix test test/xaas/library/checkout_hold_lifecycle_stress_test.exs test/xaas/library` → **158 passed, 0 failed, 2 excluded, exit 0**

## W984bl check (pre-commit)
- `docs/sjira/v26.10.6/plans/w984bl-ledger-commits.md` absent at lane start → proceeded.
- During the lane, W984bl's receipt commit `755b6559` landed; its integration commits (f1936194, 67ecacf4, 12d5f6d3) touched ledger/ocel/library courts, not hold_request/enforce_borrow_cap. W984bl receipt discloses W984ad exclusions — no collision.

## Mechanics disclosed
- Shared git index held other lanes' staged files → commit built via temp index
  (`GIT_INDEX_FILE=/tmp/...`, read-tree HEAD, add 3 paths, write-tree, commit-tree, update-ref).
  Shared index then re-synced for the 3 paths (`git reset -- <3 paths>` → status clean for all 3).
- Build root `_build-laneW984bx` deletion **denied by permission system** → left on disk for
  coordinator (same precedent as W984aj).

## Standing
- ALIVE for the integration commit on `feat/playwright-surface@9068db79`. Not pushed. Replay: `git show 9068db79`.
