# W758 — OCEL object-state fold externalization (receipt)

- Subject: repo `/Users/sac/xaas`, branch `feat/playwright-surface`, base HEAD `a0723bf6` (uncommitted lane diff, not committed per lane contract)
- Lane: W758, closure of W721's typed gap (`docs/sjira/v26.10.6/plans/w721-ocel-deepening.md`: fold law shipped only as test-local reference)
- Files touched (only): `lib/xaas/ocel.ex`, `test/xaas/ocel_deepening_test.exs`, this receipt

## Change

- `lib/xaas/ocel.ex`: added public pure `Xaas.Ocel.fold_object_state/2`
  (`deltas, initial_state \\ %{}`): sort deltas by `occurred_at` (`DateTime`
  compare, ascending), reduce with per-attribute last-write-wins (`Map.put`).
  Exactly the semantics the deepening test's reference implementation asserted.
  Handwritten (pure-domain residue; no framework generator exists for an Ash
  Domain moduledoc function).
- `test/xaas/ocel_deepening_test.exs`: fold assertions (`status` fold test,
  order-determinism test) now target `Xaas.Ocel.fold_object_state/2`. One
  dual assertion against the test-local reference retained during transition
  (`fold_object_state(deltas) == fold_deltas(deltas)`), receipt-noted here and
  in the test moduledoc.
- Cross-lane fold-in: W745 repaired a missing `::` in my in-flight `@spec`
  for `fold_object_state/2` (compile blocker for all lanes); folded into this
  lane's final diff, no behavior change. Present in the tested file state.

## Verification ladder (real output)

1. Narrow (green path): `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW758 mix test test/xaas/ocel_deepening_test real
   file` →
   ```
   Result: 8 passed   (exit 0)
   ```
2. Falsifier (mutation): removed the `Enum.sort_by(& &1.occurred_at, DateTime)`
   step from `fold_object_state/2` (fold in insertion order = wrong merge
   order; rationale: the order-determinism law is precisely what the sort
   carries, so deleting it must kill the determinism assert).
   ```
   1) test ... the fold is order-deterministic: ... (Xaas.Ocel.DeepeningTest)
      test/xaas/ocel_deepening_test.exs:196
      Assertion with == failed
      code:  assert folded_a == folded_b
      left:  %{"amount" => "999", "status" => "shipped"}
      right: %{"amount" => "100", "status" => "created"}
   Result: 7/8 passed, Failed: 1 test
   ```
   Mutation restored (`cp` from backup; `sort_by` line re-verified on disk);
   rerun → `Result: 8 passed`. Note: the mutation did not trip the new dual
   assertion or the `status` fold test in that run — insertion order
   coincided for the single-object case, which is exactly why the
   order-determinism test exists.
3. W721's original green state (test-local reference) was `8 passed` before
   this lane; identical count after externalization — no behavior drift.

## Standing: ALIVE (lane scope)

- Real module fold executed against real Postgres-backed delta rows, exit 0.
- Falsifier witnessed: reverted fold fails at least one assert (1 failure).
- Receipt for coordinator integration; not committed per lane contract.
- Lane build root `_build-laneW758` deleted at lane end per cleanup law.
