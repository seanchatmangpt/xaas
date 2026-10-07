# W928 — gymact_surface_deepening hd() hygiene (receipt)

- **Lane**: W928, v26.10.6 campaign, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`. No commit made (per lane contract; diff uncommitted).
- **Task**: W900 batch-2 receipt row 2 (W674-GAP-2 PARTIAL_ALIVE): 4/11 tests in
  `test/xaas/operations/gymact_surface_deepening_test.exs` failed on their own
  unfiltered `Ash.read!(ActuationReceipt) |> hd()` reading the OLDEST durable
  receipt in the shared test DB (poisoned by an unrelated witness row).
- **Base**: HEAD `a0723bf6` at lane start; shared tree moved underneath during
  the run (see W838-G1 note below).

## Repair (test-side only, one file)

`test/xaas/operations/gymact_surface_deepening_test.exs`:

- Added `require Ash.Query` and aliases `Xaas.Operations.{ActuationIntent, ActuationReceipt}`.
- New helpers `sealed_intent!(key)` (intent filtered by the test's own
  `idempotency_key`) and `sealed_receipt!(key)` (receipt filtered by the sealed
  intent's `intent_id` — ActuationReceipt has no idempotency_key attribute; the
  intent is the discriminator). Replaced all 8 unfiltered `|> hd()` reads in the
  four failing tests (the :failed http, :failed transport, :episode_id_required,
  and :cut_required courts), plus the `Ash.count` receipt assertion now counts
  only the test's own receipt via `intent_id`.

No production code touched. W674-GAP-2's typed refusal itself was already real
(the `{:error, %Refusal{}}` asserts passed pre-fix); only the durable-seal reads
were poisoned.

## Verification (real tails, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW928)

- Before (W900's run + this lane's first run): **7/11 passed, 4 failed**, all
  four failures at the unfiltered `hd()` reads.
- Interim: first full-suite compile under the lane build root hit a shared-tree
  compile break in `lib/xaas/governance/audit_export_token.ex` ("Duplicate
  routes defined for patch: /:id") — another lane's in-flight file, not this
  file. Per the W838-G1 wait-and-retry protocol, one retry after 300s cleared it
  (the owning lane landed its fix); second failure class was my own missing
  `require Ash.Query`, fixed immediately.
- After, run A: **Result: 11 passed** (0.7s), exit 0.
- After, run B (confirmation): **Result: 11 passed**, exit 0.

## Standing

ALIVE for the hygiene repair: the court is green twice consecutively on the
current tree and no longer depends on shared-DB read order — filtering by the
test's own minted key makes concurrent lanes and prior-run poison irrelevant.
W674-GAP-2 row closes: typed refusals + durable :refused seals now witnessed by
a non-pollutable court. Mutation rationale: reverting any helper back to the
unfiltered read reintroduces exactly the W900-observed 4-failure mode under a
poisoned DB (observed pre-fix, not re-executed post-fix).

## Cleanup

Deletion of `_build-laneW928` was attempted at lane end but refused by the
permission gate; the directory is LEFT IN PLACE for the coordinator to delete
(lane lease, not an asset — still subject to the fanout cleanup law at
integration).
