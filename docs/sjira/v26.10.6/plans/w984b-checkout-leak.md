# W984b — checkout-row "leak" triage (W982e gate-5 persistent #3/#4)

Subject: /Users/sac/xaas @ bf9f5cb9 (branch feat/playwright-surface), lane W984b, no commit.

## Diagnosis

The 2 persistent failures from `w982e-gate5-rerun.md` —
`Xaas.Library.CheckoutPolicyDeepeningTest` "return on an exhausted book hands the
copy to the oldest hold" (`:172`) and "no notification record is created by
fulfillment -- PubSub broadcast only" (`:230`), both on
`open_checkouts_for(waiting.id) == []` — are **the same stale-contract pair W982r
named** (w982r-nextread-cluster.md #1). Not a leak.

Landed contract: commit `b2758300` (W970b, W796-G3 close) made `HoldRequest :fulfill`
mint a real hand-off Checkout (`lib/xaas/library/hold_request.ex`, after_action
create with `book_id/user_id/school_id` from the hold). The tests predate that and
assert the old "no Checkout row" contract.

Fresh-root run (clean `_build-laneW984b`, before any edit) — real failure tail:
left is exactly one correct hand-off row:

```
code:  assert open_checkouts_for(waiting.id) == []
left:  [%Xaas.Library.Checkout{id: "e769798c-...", status: :borrowed,
         returned_at: nil, book_id: "0f6a529c-...", user_id: "5b3731c7-...",
         school_id: "willow-creek", renewed_count: 0}]
right: []
Result: 11/13 passed, Failed: 2 tests
```

Leak-class checks (minted row audited): exactly one row, correct book binding,
correct patron (hold.user_id), status `:borrowed`, `returned_at nil` — no
hold-less mint, no duplicate, no wrong-patron row. lib/ is correct; **test
fix** branch taken.

## Fix (tests to the landed contract)

`test/xaas/library/checkout_policy_deepening_test.exs` only (+26/−10):
- both tests now assert exactly one open checkout for the waiting reader,
  bound to `book_id` == the book, `user_id` == waiting, `:borrowed`,
  `returned_at == nil`;
- moduledoc (b) updated to the W970b semantics.

No `lib/xaas/library/` change made (not warranted). Pre-existing uncommitted
`lib/xaas/library/reactors/steps/score_book.ex` diff is W982r's lane diff —
untouched.

## Verification (real runs, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW984b, asdf toolchain)

| run | scope | result |
|---|---|---|
| pre-edit | full file, fresh build root | 11/13 passed, 2 failed (the named pair) |
| post-edit | full file | 13 passed, 0 failed |
| suite ×1 | `mix test test/xaas/library` | 157 passed, 2 excluded, 0 failed |
| suite ×2 | `mix test test/xaas/library` | 157 passed, 2 excluded, 0 failed |

## Standing / notes

- Disposition: 2/2 persistent failures = stale-contract (test-shape defect),
  fixed in tests; lib fix branch not taken.
- W982j territory (`checkout_hold_lifecycle_stress_test.exs`) untouched; its
  tests pass within the 157.
- `_build-laneW984b` deletion denied by the permission system — left on disk
  for coordinator cleanup per the same-checkout-fanout cleanup law.
- No commit made (per lane orders).
