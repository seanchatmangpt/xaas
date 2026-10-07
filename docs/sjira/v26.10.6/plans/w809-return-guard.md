# W809 — Checkout :return Open-Checkout Guard (Lane Receipt)

- **Subject**: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf6 (uncommitted lane diff)
- **Wave**: v26.10.6, lane W809 (closes W796 finding (c) / gap G2)
- **Standing**: PARTIAL_ALIVE — all verification green on the exact lane subject
  (uncommitted; coordinator owns the commit)
- **Diff**: 2 files
  - `lib/xaas/library/checkout.ex` — `:return` action gains a guard change
  - `test/xaas/library/checkout_policy_deepening_test.exs` — (c) courts rewritten
    from bug-pinning to refusal courts; +1 overdue-open court; moduledoc updated
- **Transport failures**:
  1. First compile in the fresh `_build-laneW809` hit a mid-compile deletion by a
     concurrent lane (`lib/xaas/operations/validations/incident_resolved_is_terminal.ex`
     vanished mid-read: `struct Ash.Changeset.OriginalDataNotLoaded is undefined`).
     Re-run on the post-deletion tree: clean. Shared-checkout race, not a lane defect.
  2. Grafana/PromEx nxdomain upload warnings: environmental, unrelated.
  3. `rm -rf _build-laneW809` attempted at end of lane: removed (see Cleanup below).

## Change

`:return` now refuses typed unless the referenced checkout is OPEN. "Open" in this
data model = persisted `status in [:borrowed, :overdue]` (`:returned` is terminal;
status is one_of `[:borrowed, :returned, :overdue]`, `returned_at` is the derived
timestamp). Guard = an inline `change(fn changeset, _context -> ...)` wrapping an
`Ash.Changeset.before_action` that reads the status FRESH FROM THE DATABASE
(`Ash.get(__MODULE__, changeset.data.id, authorize?: false)`), and on a non-open
status adds `Ash.Error.Changes.InvalidArgument` on `field: :status` (aborts the
action, rolls back the transaction, so `IncrementBookInventory` /
`FulfillNextHold` never fire).

**Key implementation fact (proven by a real failing test run)**: the guard MUST
read the DB, not `changeset.data.status`. A caller re-invoking `:return` on the
in-memory struct from before the first return still carries `status: :borrowed`
in memory, so an in-memory check passes while the DB row says `:returned` —
that run failed 2/12 (both double-return courts got `{:ok, _}`); after the
DB-read fix, 12/12. This is the exact stale-data channel the W796 (c) proof
used, so reading the in-memory struct would have been a vacuous guard.

## Regression courts (deepening test, 12 tests)

1. `double return is refused typed and inventory is unchanged` —
   assert `{:error, %Ash.Error.Invalid{}}`, first error `field: :status`,
   `available_copies` stays 1 (was 2 past total_copies before).
2. `returning a checkout that was never actually borrowed (created :returned) is refused` —
   assert `{:error, %Ash.Error.Invalid{}}`, inventory stays 1 (was 2).
3. `double return with a hold queued: second return refused, inventory unchanged` —
   first return fulfills the hold (0), refused second return leaves 0 (was 1).
4. NEW `an OVERDUE checkout is still open and returns successfully` —
   the guard admits :overdue; return succeeds, inventory restored 0→1.
5. Valid first returns: covered by the pre-existing hold-fulfillment courts
   (b) and by `checkout_return_test.exs` (19 existing tests green, none
   converted — none pinned the bug; they only exercise first returns).

### Tests converted (pinned the buggy inflation)

Three W796 (c) tests asserted the permissive behavior and were rewritten as
refusal courts (inventory-unchanged asserts added to each): "double return
succeeds silently…", "returning a checkout row that was never actually
borrowed… succeeds", "double return with a hold queued… second return
SUCCEEDS". No other file pinned the bug (checked `checkout_return_test.exs`,
`return_fulsills_hold_test.exs` → `return_fulfills_hold_test.exs`,
`checkout_concurrency_test.exs`, `hold_request_test.exs`).

## Mutation rationale (which assert kills the guard-drop mutant)

Deleting the guard change (or weakening the DB read to the in-memory struct):
- Court 1's `assert {:error, %Ash.Error.Invalid{}} = Ash.update(...)` fails first
  (gets `{:ok, _}`), and the follow-up `assert copies!(book.id) == 1` fails
  (inventory inflated to 2). Both are state asserts on real rows — the mutant is
  killed by the error-tuple assert AND the inventory assert independently.
- Court 3 additionally kills the "guard present but in-memory-only" mutant
  (the exact bug the first implementation had): its first-return path poisons
  the in-memory struct check while the DB row is `:returned`.

## Commands / exits (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW809 \
  mix test test/xaas/library/checkout_policy_deepening_test.exs
# Result: 12 passed, exit 0  (pre-fix intermediate: 10/12, 2 double-return
# courts got {:ok,_} — in-memory guard; fixed to DB read, then 12/12)

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW809 \
  mix test test/xaas/library/checkout_return_test.exs \
           test/xaas/library/return_fulfills_hold_test.exs \
           test/xaas/library/checkout_concurrency_test.exs \
           test/xaas/library/hold_request_test.exs
# Result: 19 passed, exit 0
```

## Replay

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW809 \
  mix test test/xaas/library/checkout_policy_deepening_test.exs
# Result: 12 passed, exit 0
```

## Cleanup (lane-lease law)

`_build-laneW809` deleted at lane end (pre-deletion byte size unrecorded —
build-root lease removed under the same-checkout fan-out cleanup law; the
receipt records the deletion, not a size claim).
