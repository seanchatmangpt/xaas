# W984i — avatar-2 hold-cascade gate-5 failure (receipt)

Lane: W984i, xaas v26.10.6, checkout `/Users/sac/xaas`, branch `feat/playwright-surface` @ 49a719ab.
Task source: W982e residual list (`w982e-gate5-rerun.md` #4).

## Test identity

`XaasWeb.A2A.ReturnHoldCascadeAvatarsTest` — "avatar 2: return with exactly
one active hold …" — `test/xaas_web/a2a/return_hold_cascade_avatars_test.exs:145`.

Failure (W982e log `/tmp/w982e-gate5-rerun.log`, both rerun runs):

```
assert after_checkout_count == before_checkout_count
left: 2, right: 1
```

## Coordination check

NOT one of W984b's pair. W984b owns `test/xaas/library/checkout_policy_deepening_test.exs`
(`open_checkouts_for` row-leak). The avatar-2 test lives in
`test/xaas_web/a2a/return_hold_cascade_avatars_test.exs` and asserts a
different surface (the return→hold-fulfillment cascade). No
duplicate-of-w984b refusal.

## Root cause

Stale test, not a lib bug. Commit **b2758300** (W970b, closing W796-G3)
intentionally changed `Xaas.Library.HoldRequest`'s `:fulfill` action
(`lib/xaas/library/hold_request.ex`, final `change` block) to mint a real
physical hand-off `Checkout` row (`:create`) for the hold holder in the same
`after_action` transaction as the `Book.borrow_copy` inventory decrement.
The avatar-2 test still asserted the pre-W970b design ("no Checkout row is
auto-created"), so it now deterministically fails against the current,
intended lib behavior. W972's "flake" classification was wrong for the same
reason — the failure is deterministic post-b2758300.

## Fix (test-only; no lib change needed — current lib behavior is the
admitted W970b design)

`test/xaas_web/a2a/return_hold_cascade_avatars_test.exs`, avatar 2:

- moduledoc avatar-2 entry rewritten to describe the W970b hand-off design.
- test renamed to "…mints exactly one open Checkout row for the hold holder
  (W970b hand-off design)".
- assertions flipped to the current contract: checkout count +1; exactly one
  open `:borrowed` Checkout row exists for `(book_id, waiting_reader.id)`.

Avatar 3 (multi-hold ordering) unaffected — it never asserted checkout
counts.

## Disposition / standing

- Runs (fresh lane build root `_build-laneW984i`, `MIX_ENV=test`,
  asdf toolchain): **3 × "Result: 5 passed"** (`mix test
  test/xaas_web/a2a/return_hold_cascade_avatars_test.exs`, exit 0 each).
- Classified: persistent-real (stale-test), fixed forward, ALIVE at 3/3 green.
- Not committed (per lane contract; coordinator owns integration).
- `_build-laneW984i` left in place for the coordinator (lane-local `rm -rf`
  was permission-denied); it is a lease, safe to delete at integration.
