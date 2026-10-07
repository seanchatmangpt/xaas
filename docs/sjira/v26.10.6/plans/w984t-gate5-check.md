# W984t — Gate-5 residual spot-check (W982e closing state)

Subject: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `e12615af`
(dirty tree, sibling lanes in flight). No commit. Lane W984t,
`MIX_BUILD_ROOT=_build-laneW984t` (fresh root), asdf elixir 1.20.2-otp-28,
MIX_ENV=test.

Method: per orders, NOT a gate rerun. Per residual: record per owner's receipt
where one exists on disk; else run the owning test file once on a fresh root.

## Disposition table (5 residuals of w982e-gate5-rerun.md)

| # | residual | owner | verdict | standing |
|---|---|---|---|---|
| 1 | checkout-row "leak" pair (CheckoutPolicyDeepeningTest `:172`/`:230`) | W984b (receipt on disk) | **closed-by-lane-W984b** — w984b-checkout-leak.md: stale-contract (tests predate W970b `b2758300` hold-fulfill Checkout mint); tests updated to landed contract, post-edit 13/13 + `test/xaas/library` ×2 at 157 passed / 0 failed | RESOLVED (test-shape) |
| 2 | W973b terminal guard (`enrollment_journey_court_test.exs:439`) | W984c | **still-open → now passing**: no w984c receipt on disk at check time; my own run of the file on fresh root gave **0 failures** — the terminal-guard test now passes on the current tree (sibling `registration.ex` edits present) | PASSING (unreceipted owner) |
| 3 | route-castle type-only GraphQL (`route_castle_run_surface_test.exs:195`) | W984f | **still-open → now passing**: no w984f receipt on disk at check time; my run of the file: **0 failures** | PASSING (unreceipted owner) |
| 4 | avatar-2 hold cascade (`return_hold_cascade_avatars_test.exs`) | W984i | **still-open → now passing**: no w984i receipt on disk at check time; my run of the file: **0 failures** | PASSING (unreceipted owner) |
| 5 | approval/org-mismatch pair (ApprovalPatchSlaCreditApplyControllerTest PATCH+POST org-mismatch) | none | **PERSISTENT, not flake**: ran ×2, both runs failed exactly the same 2 tests, 6/8 each (`Result: 6/8 passed` both times, different order only). W982e's flake classification does not reproduce; reclassify **persistent** | STILL-OPEN (unowned) |

Rows 2–4 combined run (one `mix test` invocation, 3 files, fresh root, seed
512057):

```
Finished in 4.9 seconds (0.00s async, 4.9s sync)
Result: 20 passed
```

Row-5 runs (`test/xaas_web/controllers/approval_patch_sla_credit_apply_controller_test.exs`):

```
run 1: 6/8 passed — PATCH org-mismatch + POST org-mismatch failed (== assertion)
run 2: 6/8 passed — same 2 failed
```

Log: `/private/tmp/claude-501/-Users-sac-xaas/91f5365d-5434-44dc-a0ee-ffb6967a2a2a/tasks/bhjuyxcp0.output`.

## Notes

- Rows 2–4 pass with **no owner receipt on disk** — the tree state that closes
  them is sibling-uncommitted work (registration.ex, approval/lib diffs in
  flight). Treat as provisional closure pending W984c/W984f/W984i receipts;
  ALIVE requires the owner lanes to land their receipts.
- Row 5: do not accept "flake" — 2/2 identical failures here.
- `_build-laneW984t`: `rm -rf` denied by the permission system — left on disk
  for coordinator cleanup per the same-checkout-fanout cleanup law.

## Standing

Gate-5 residual surface: **PARTIAL_ALIVE** — 1 residual closed-by-receipt
(W984b), 3 passing on the current tree but unreceipted by their owning lanes,
1 residual reclassified persistent (approval/org-mismatch pair, unowned).
Full-gate ALIVE falsifier unchanged: gate-5 rerun with 0 failures on a
quiescent tree.
