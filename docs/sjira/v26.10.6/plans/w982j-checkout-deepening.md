# W982j — Library checkout/hold lifecycle deepening court

Lane: W982j, xaas v26.10.6, branch `feat/playwright-surface`. Read-only outside
`test/xaas/library/` + this receipt; nothing committed.

## Subject

- New court: `test/xaas/library/checkout_hold_lifecycle_stress_test.exs`
  (7 tests, real sandboxed Postgres, no mocks).
- Sources read before asserting:
  `lib/xaas/library/{checkout,hold_request,book}.ex`,
  `lib/xaas/library/changes/{decrement,increment}_book_inventory.ex`,
  `lib/xaas/library/changes/fulfill_next_hold.ex`.

## Coverage (per scenario verdicts)

1. **Concurrent double `:fulfill` on one hold (Task.async_stream, ×2 real
   processes over one shared sandbox conn, established lane pattern) —
   PASS.** Exactly one success; loser refused typed. Real typed loser error
   (observed): `Invalid value provided for available_copies: No shelf copies
   currently available` from the atomic `Book.borrow_copy` decrement — not the
   status validation, because under serialized connection both racers read
   `status :active`. Test accepts either typed refusal.
2. **Borrow cap enforcement — PASS.** Patron at cap: next `:borrow` refused
   with the real typed error, naming `per-student borrow cap exceeded` and
   `(limit 3)`; refusal precedes `DecrementBookInventory` (no copy burned, no
   ghost row).
3. **Return-releases-slot — PASS.** Blocked hold on a 0-copy book is
   fulfilled by another patron's `:return` (net inventory 0, waiting reader
   holds a real `:borrowed` Checkout); pre-return non-fulfillment asserted;
   post-return invariants PASS: copy restored, exactly one row, double return
   refused with the real W809 typed message
   `cannot return a checkout that is not open (status: :returned)`, refused
   double return does not re-increment inventory; returned slot frees the cap
   and the next borrow is a NEW row (history preserved, first book's returned
   row untouched).
4. **Copy-state invariants post-return — PASS** (see 3; no ghost rows, no
   inventory inflation from a refused return).

## REAL FINDING (gap, pinned not asserted-green): cap bypass on the hold-fulfillment mint path

`HoldRequest :fulfill` mints the W970b hand-off Checkout via the PRIMARY
`create :create` action, while the per-student cap guard lives only on
`create :borrow`. The cap is structurally unreachable on the fulfillment path.
Observed (real Postgres, both runs): a patron with 3 open checkouts fulfills a
hold and ends with **4 open checkouts, no typed refusal anywhere**. Test
`"KNOWN GAP: hold fulfillment for a patron already at the cap succeeds,
minting a cap-exceeding checkout"` pins this behavior bidirectionally: moving
the guard will fail this test and force a deliberate decision. Typed repair
shape: move the cap guard to a change shared by `:borrow` and the fulfillment
mint (or onto `:create`), then flip the pinned test.

## Verification (real tails)

```
# warm lane root _build-laneW982j (after 4 fix iterations):
$ mix test test/xaas/library/checkout_hold_lifecycle_stress_test.exs
Result: 7 passed          # /tmp/w982j_run4.log

# ×2 on a fresh root (_build-laneW982j-fresh, full dep recompile):
$ mix test test/xaas/library/checkout_hold_lifecycle_stress_test.exs
Result: 7 passed          # /tmp/w982j_fresh1.log  (fresh-root run 1)
Result: 7 passed          # /tmp/w982j_fresh2.log  (fresh-root run 2)
```

Note: two fresh-root attempts were SIGTERM-killed at the 10-minute background
limit mid-dep-compile and resumed; the resumed compile completed and both
final runs are the ones recorded. Seeds differed per run (default randomize).

## Standing

- Court: **ALIVE** — 7/7 passed ×3 (warm root, fresh root ×2).
- Finding standing: observed on the exact subject, twice per run; pinned by
  test. Not repaired (lane scope: tests + receipt only).
- Lane build roots `_build-laneW982j` and `_build-laneW982j-fresh` LEFT ON
  DISK for the coordinator: this session's `rm -rf` was denied by the
  permission system (three attempts). Coordinator should delete both at
  integration per the lane-lease law.
