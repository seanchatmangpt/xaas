# W974 — Castle Refusal Negative Test: Self-Recursive `castle_manufacture/2` Fix

- **Subject**: `/Users/sac/xaas` @ `fab56ae1` (working tree, uncommitted), branch `feat/playwright-surface`, lane W974
- **Date**: 2026-10-07
- **Closes**: the pre-existing sibling BLOCKED docketed by W863
  (`docs/sjira/v26.10.6/plans/w863-castle-protocol-fix.md`)
- **Write scope honored**: only `test/xaas/castle_refusal_negative_test.exs` + this receipt. No commit made.

## Defect (from W863) and fix

`defp castle_manufacture/2` (former lines 301-302, committed in 160f23f2) re-entered
itself inside `with_castle_lock/1`:

```elixir
defp castle_manufacture(intent, witness) do
  with_castle_lock(fn -> castle_manufacture(intent, witness) end)   # self-recursive
end
```

Every manufacture-based test therefore acquired the /tmp exclusive-create lock and then
spun forever as its own contender — 13/19 tests ExUnit 60s-timeout inside
`acquire_castle_lock` (W863 lsof: test beam held the lock fd while sleeping on `eexist`).

**Fix — one call site, helper kept:**

```elixir
# W974: this helper previously re-entered itself inside with_castle_lock/1 —
# infinite self-recursion, so every manufacture-based test deadlocked on its
# own /tmp file lock (13/19 ExUnit timeouts; W863 lsof evidence). Call the
# real kernel CLI manufacture/2 under the lock instead.
defp castle_manufacture(intent, witness) do
  with_castle_lock(fn -> Xaas.Castle.Kernel.CLI.manufacture(intent, witness) end)
end
```

`Xaas.Castle.Kernel.CLI.manufacture/2` is defined at `lib/xaas/castle.ex:588`
(`@behaviour Xaas.Castle.Kernel`, `@impl true`) — the same kernel the court suite
(`castle_execute_court_test.exs`) exercises; the helper's `(intent_map, witness_map)`
shape is exactly its signature, so no W828-contract reshaping was needed.

## Verification (real runs, lane build root `_build-laneW974`, isolated lock `/tmp/w974-castle.lock`)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW974 \
  XAAS_CASTLE_TEST_LOCK=/tmp/w974-castle.lock \
  mix test test/xaas/castle_refusal_negative_test.exs
# Run 1: 19 passed, Finished in 4.9 seconds (0.00s async, 4.9s sync)  [exit 0]
# Run 2: 19 passed                                                    [exit 0]
```

Before: 13/19 ExUnit 60s-timeouts (W863 receipt, reproduced solo at HEAD a0723bf6).
After: 19/19, wall time 4.9s — all timeouts gone.

## Cross-file regression check

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW974 \
  XAAS_CASTLE_TEST_LOCK=/tmp/w974-castle.lock \
  mix test test/xaas/castle_execute_court_test.exs
# 10 passed [exit 0] — matches W863's 10/10, no cross-file regression
```

## Mutation rationale

Reverting the fix (`Xaas.Castle.Kernel.CLI.manufacture` → `castle_manufacture`)
restores the infinite self-recursion under the held lock; every manufacture-based test
re-deadlocks on its own file lock. The failure mode is witnessed by W863's lsof evidence
(beam held fd on the lock while spinning on `eexist`) and by the 13/13-timeout baseline;
the fix's 4.9s full-file pass is the positive half of the same falsifier.

## Standing vocabulary

- `castle_refusal_negative_test.exs`: **ALIVE** (19/19 x2, 4.9s, timeouts eliminated)
- `castle_execute_court_test.exs` (W863 surface): **ALIVE** (10/10, unchanged)
- `:castle_kernel` court with the real CASTLE binary: not run (same disclosed exclusion as W828/W863)

## Lane lease

`_build-laneW974` deleted after final run per the lane-lease law. Isolated lock file
`/tmp/w974-castle.lock` removed.
