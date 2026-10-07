# w984ad — fulfill-path borrow cap (W982j pinned finding close)

Standing: **ALIVE** (real runs, real Postgres sandbox, lane build root).
Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface`, uncommitted lane diff.

## Finding closed

W982j (w982j-checkout-deepening.md, KNOWN GAP test) pinned: `HoldRequest :fulfill`
mints the W970b hand-off Checkout via the primary `create :create`, which carries no
per-student borrow cap — the cap lives only on `Checkout` `create :borrow` — so a
capped patron fulfilled into a 4th open checkout unrefused.

## Fix shape

Shared form extracted; fulfillment path now runs the same guard before the mint:

- **New** `lib/xaas/library/changes/enforce_borrow_cap.ex` —
  `Xaas.Library.Changes.EnforceBorrowCap`: `@max_open_checkouts_per_student 3`,
  `check/2` counts open (`:borrowed`/`:overdue`) checkouts fresh from the database
  (W809/W902 persisted-state discipline) and refuses typed with the identical
  `InvalidArgument` field/message shape the `:borrow` inline guard produces;
  also a `use Ash.Resource.Change` facade so `:borrow` can migrate onto it later.
- `lib/xaas/library/hold_request.ex` `:fulfill` mint change: cap check now runs
  inside the existing `after_action` **before** the Checkout mint. At/over cap:
  `{:error, InvalidArgument "per-student borrow cap exceeded: cannot fulfill hold
  into a new open checkout (limit 3); return one before fulfilling this hold"}` —
  the after_action error rolls back the hold status + inventory decrement
  atomically (hold stays `:active`, no copy burned, no ghost Checkout).
- `Checkout` `create :borrow` inline guard intentionally left untouched
  (file-ownership boundary); migrating it onto the shared module is a coordinator
  decision. `checkout_policy*` tests untouched.

## Test flip (bidirectional)

`test/xaas/library/checkout_hold_lifecycle_stress_test.exs` — KNOWN GAP test
replaced with two pins:

1. **Negative**: capped patron (3 open) `:fulfill` → `{:error, _}` containing
   `per-student borrow cap exceeded`; hold stays `:active`; no Checkout minted;
   `available_copies` back to 1; open count still exactly 3.
2. **Positive**: patron under cap (1 open) fulfills normally — hand-off Checkout
   minted `:borrowed`, `fulfilled_at` set, inventory 1 → 0.

## Commands / exits (real tails)

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ad mix test test/xaas/library/checkout_hold_lifecycle_stress_test.exs
  → 8 passed, exit 0
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ad mix compile   → clean
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ad mix test test/xaas/library/   (×2)
  → 158 passed, 2 excluded, exit 0   (both runs)
```

158 = 157-green baseline + 1 (KNOWN GAP replaced by two tests). W982r's
uncommitted `score_book.ex` fix left in tree, untouched.

## Transport failures

Two initial `mix test test/xaas/library/` runs on the fresh lane root aborted with
`** (Mix) Could not start application ash_graphql: could not find application
file: ash_graphql.app` despite the `.app` being present in the root's ebin; a
`mix compile` pass cleared it and both subsequent runs were green. Classified
transient lane-root bootstrap, not a subject failure.

## Cleanup

`rm -rf _build-laneW984ad` was denied by the permission system — build root left
in place for coordinator deletion (per dispatch fallback).

## Falsifier (already run)

The flipped stress file: reverting the hold_request.ex/changes edit makes test 1
fail (fulfill succeeds for capped patron) — the old KNOWN GAP assertion, pinned
pre-fix in w982j run2.
