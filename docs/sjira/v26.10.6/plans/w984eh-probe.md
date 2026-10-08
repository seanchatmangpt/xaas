# W984eh — unclaimed-family probe: returns/hold-cascade domain

Lane: W984eh · branch `feat/playwright-surface` · NO commit (per dispatch)
Date: 2026-10-07

## Subject

- Court file (new): `test/xaas/library/cascade_court_w984eh_test.exs`
- Lib family probed: `lib/xaas/library/changes/fulfill_next_hold.ex`,
  `lib/xaas/library/hold_request.ex`, `lib/xaas/library/checkout.ex`,
  `lib/xaas/library/changes/enforce_borrow_cap.ex`

## Census — per-module disposition

| module / file | test exercisers | disposition |
|---|---|---|
| `Xaas.Library.Changes.FulfillNextHold` | return_hold_cascade_avatars_test.exs; return_fulfills_hold_test.exs; checkout_hold_lifecycle_stress_test.exs | **covered, except `fulfill_next_hold.ex:48-49` error-propagation branch (`{:error, error} -> {:error, error}` on inner `:fulfill`) — uncovered → court written** |
| `Xaas.Library.HoldRequest` (:place/:fulfill/:cancel/:expire/:expire_stale/reads) | hold_request_test.exs; return_fulfills_hold_test.exs; next_read_test.exs; oban_depth_w984cn_test.exs; system_authority_capability_chicago_test.exs; ultracode/system_authority_chicago_test.exs; circulation_borrow_reactor_test.exs | covered (all lifecycle actions + `:expirable` + scheduled `:expire_stale` witnessed) |
| `Xaas.Library.HoldRequest :fulfill` W984ad borrow-cap refusal | checkout_hold_lifecycle_stress_test.exs:182-202 | covered on *direct* `:fulfill` only; the cascade path was the gap (see row 1) |
| `Xaas.Library.Checkout` (:borrow/:return/double-return refusal) | checkout_return_test.exs; checkout_concurrency_test.exs; checkout_policy_deepening_test.exs; checkout_hold_lifecycle_stress_test.exs; avatars tests | covered |
| `Xaas.Library.Changes.EnforceBorrowCap` (check/2, change/2, max_open_checkouts) | checkout_hold_lifecycle_stress_test.exs; new court | covered (both call paths: `change` on `:borrow`, `check/2` on `:fulfill` mint) |
| `Xaas.Library.Reactors.CirculationBorrowReactor` | circulation_borrow_reactor_test.exs | covered |
| FulfillNextHold `{:ok, nil}` empty-queue branch | return_fulfills_hold_test.exs:97-108; avatars test avatar 1 | covered |
| FulfillNextHold read-error / book-lookup-error branches | — | unreachable through real state (FK RESTRICT; documented in return_fulfills_hold_test.exs:136-144) — typed unreachable, not courted |
| FulfillNextHold `book_id` nil early-return (line 62-63) | — | unreachable: `book_id` is `allow_nil?(false)` on Checkout |

## New court (Chicago, zero mocks)

`test/xaas/library/cascade_court_w984eh_test.exs` — 2 tests:

1. Return whose oldest active hold belongs to a capped reader (cap driven
   by 3 real `:borrow` creates on 3 real books): `Ash.update` returns
   `{:error, _}`, and full-transaction rollback asserted across all three
   aggregate roots — borrower's checkout stays `:borrowed`, inventory
   back to 0, hold stays `:active`/unfulfilled, no hand-off Checkout.
   Kills the pre-P2 mutation (`{:ok, checkout}` on fulfill failure).
2. Second active hold behind the capped oldest hold untouched; no
   hand-off row for either reader.

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984eh
  mix test test/xaas/library/cascade_court_w984eh_test.exs`
  → `Result: 2 passed`, **exit 0** (fresh lane build root; 1.6s sync).
- Mock gate: `scan_mock_usage(["test","lib"])` → `[]` (expect [] satisfied).

## Cleanup

- `rm -rf _build-laneW984eh`: **DENIED** by session permission system
  (two attempts refused). Lane build root `/Users/sac/xaas/_build-laneW984eh`
  REMAINS ON DISK — coordinator must delete it at integration per the
  cleanup law.

## Standing

ALIVE (lane-local): uncovered state-bearing branch found, courted, 2/2
passing exit 0, mock gate clean. NO commit made.
