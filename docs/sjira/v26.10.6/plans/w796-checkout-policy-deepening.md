# W796 — Checkout Circulation Policy Deepening (Lane Receipt)

- **Subject**: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf6 (uncommitted lane file)
- **Wave**: v26.10.6, lane W796
- **Standing**: PARTIAL_ALIVE (11/11 real sandbox Postgres tests green on the exact subject)
- **Diff**: +1 file — `test/xaas/library/checkout_policy_deepening_test.exs` (11 tests, no lib changes)
- **Transport failures**: first `mix test` run hit the 600s foreground timeout
  mid-compile (fresh lane build root compiles all deps); completed in background,
  exit 0. `rm -rf _build-laneW796` denied by permission system — build root left
  for coordinator (per dispatch contract's "else leave for coordinator" clause).
  Grafana/PromEx nxdomain warnings in output: environmental, unrelated.
- **Commands / exits**:
  - `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW796 mix test test/xaas/library/checkout_policy_deepening_test.exs`
    → `Result: 11 passed`, exit 0 (twice; second run after removing an unused-variable
    warning, no failures either run)

## Findings (asserted as real row state, no mocks)

### (a) Per-student concurrent-checkout limit: NOT ENFORCED (typed gap)
`Checkout :borrow` only decrements inventory via
`Xaas.Library.Changes.DecrementBookInventory`; nothing counts a student's open
checkouts. Proven: one student borrows all 3 copies of one book (copies → 0) and
3 different books with no aggregate cap. Standing of the *limit*: UNSUPPORTED
(absent). The tests assert the real uncapped behavior.

### (b) Hold interaction on return: AUTO-FULFILLMENT, real and enforced
`Checkout.return` → `Xaas.Library.Changes.FulfillNextHold` →
`HoldRequest :fulfill` → `Book :borrow_copy`: the returned copy is handed
directly to the oldest active hold (inventory re-decremented, never rests on the
shelf). Proven on a 1-copy book: 1→0 (borrow) →0 after return (returned then
immediately re-borrowed by the hold reader). Oldest-first is real: with two
holds (positions 1 and 2, distinct inserted_at) only the oldest is fulfilled;
the second stays `:active`. Fulfilled holds mint NO new Checkout row for the
waiting reader — the hold row itself (status `:fulfilled`, `fulfilled_at`) is
the only durable fulfillment record. No notification artifact is created
(PubSub broadcast is ephemeral only). Typed gap: a fulfilled hold does not
mint a real borrow; converting fulfillment into an actual loan is unmodeled.

### (c) Return-of-unborrowed / double-return: NO REFUSAL (typed gap)
`:return` accepts `[]` and validates nothing about prior status. Proven:
- double return succeeds silently and increments inventory twice (1→0→1→2,
  exceeding `total_copies` = 1 — no upper-bound validation);
- a checkout row minted `:returned` from birth (never borrowed via :borrow)
  returns successfully, inflating inventory to 2;
- double return with a hold queued also succeeds on the second pass
  (FulfillNextHold finds no remaining active hold → no-op; inventory still
  inflated 0→1).
Standing of the refusal contract: UNSUPPORTED (no guard exists). Tests assert
the real permissive behavior, not a desired one.

### (d) Determinism
Hold queue positions are deterministic (1, 2 by placement order); repeated
borrow/return cycles over one book are deterministic in terminal status,
returned_at non-nil, and restored inventory count (2 copies → 2 after both
returns).

## Falsifiers (all ran, none refuted the findings)
- "a per-student cap exists" — refuted by 3-copies-one-student test passing.
- "double return is refused" — refuted by double-return tests passing.
- "return fulfills all holds" — refuted by only-oldest-fulfilled test.

## Gaps typed for the backlog
1. G1: no per-student concurrent/aggregate borrow cap (UNSUPPORTED).
2. G2: `:return` has no already-returned/unborrowed guard; inventory can be
   inflated past `total_copies` (UNSUPPORTED).
3. G3: fulfilled hold mints no real Checkout row; hand-off is implicit
   (UNSUPPORTED).

## Replay
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW796 \
  mix test test/xaas/library/checkout_policy_deepening_test.exs
# Result: 11 passed, exit 0
```
