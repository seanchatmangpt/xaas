# W863 — Castle Protocol Compare Fix (W828 typed gap closure)

- **Subject**: `/Users/sac/xaas` @ `a0723bf6`, branch `feat/playwright-surface`, lane W863
- **Date**: 2026-10-07
- **Standing**: PARTIAL_ALIVE (lane surface ALIVE; one pre-existing sibling-suite BLOCKED, see below)
- **Deliverables**:
  - `lib/xaas/castle.ex` — compare-side protocol normalization (both compare sites)
  - `test/xaas/castle_execute_court_test.exs` — W828 witness tests flipped to the succeeded contract
  - this receipt

## Defect (from W828) and fix

`Xaas.Castle.Contract.identity().protocol` is the **atom** `:CASTLE_PAAS_XAAS_BRIDGE_V2`
(GGEN override, `GGEN:XAAS_CASTLE_CONTRACT` block in `lib/xaas/castle.ex`), while
`Xaas.Actuation.json_safe/1` stringifies atoms before the jsonb write. The reload compares
`checkpoint["protocol"] != contract.protocol` (atom vs string) → every lawful Execute
traversal refused `REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH`.

**Fix — compare side only.** Both protocol compares in `lib/xaas/castle.ex` were normalized
with `to_string/1` on both sides, each with a W828/W863 citation comment:

1. `Xaas.Castle.Admission.verify_checkpoint/2` (the `Admission.checkpoint/2` compare —
   the task's named site; the module lives in `lib/xaas/castle.ex`, not
   `lib/xaas/castle/admission.ex` — lane-file deviation noted, no new file created since
   `Xaas.Castle.Admission` is already defined there)
2. `Xaas.Castle.Kernel.CLI.verify_runtime_checkpoint/4` (required for the full traversal:
   the Reactor feeds the reloaded stringified checkpoint into private execute; fixing only
   (1) leaves this second atom/string compare refusing — W828's own minimal-fix note named
   both sites)

The GGEN contract block (`lib/xaas/castle.ex` GGEN override) was NOT edited;
`json_safe/1` was NOT edited.

## Court changes (`test/xaas/castle_execute_court_test.exs`)

- **(b4) flipped**: the two W828 defect-witness tests → one full-traversal regression court
  `Xaas.Castle.run/2` (prepare → witness → manufacture → durable checkpoint → private
  execute → seal) asserting the real durable row: `status == :succeeded`,
  `result["standing"] == "ALIVE"`, `result["contract"]["protocol"] ==
  "CASTLE_PAAS_XAAS_BRIDGE_V2"` (stringified), 64-hex `result_hash`/`replay_token`, and
  deterministic replay (`:replayed`, same receipt id, zero new rows). The jsonb round-trip
  test is kept as the proof of why normalization must live at the compare.
- **(c) flipped**: direct Ash-action traversal now `{:ok, result}` with stringified contract
  protocol; outer receipt honestly stays `:prepared` (seal belongs to the Reactor step).
- Refusal courts (no-context / expired / foreign-witness) stay green unchanged.
- The stub serves one combined construct+DO payload for the Reactor path (single stub
  subcommand-agnostic `cat` script; manufacture and DO validators both accept it).

## Mutation rationale

Dropping the normalization (`to_string(checkpoint["protocol"]) != to_string(contract.protocol)`
→ plain `!=`, both sites) makes the new regression court fail:

```
code:  assert {:ok, envelope} = Xaas.Castle.run(intent, ...)
left:  {:ok, envelope}
right: {:error, %Reactor.Error.Invalid{errors: [%Reactor.Error.Invalid.RunStepError{
         error: :REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH, step: :checkpoint_outer_receipt / :execute_private_action}]}}
Result: 0/1 passed
```

Witnessed by real run `/tmp/w863_mutation.log` (0/1 under mutation; 10/10 after restore).

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW863 \
  mix test test/xaas/castle_execute_court_test.exs
# Result: 10 passed — witnessed 3x (incl. post-mutation-restore final run)
```

Sibling castle suites (same battery):
`castle_refusal_negative_batch2..6 + castle_capability_intake(_runtime)` — all green in the
combined run (62/75 total; all 13 failures confined to `castle_refusal_negative_test.exs`,
see typed gap). Mock gate:
`scan_mock_usage(["test/xaas/castle_execute_court_test.exs", "lib/xaas/castle.ex"])` → `[]`.

## Pre-existing sibling failure (not session-introduced, not lane-owned)

`test/xaas/castle_refusal_negative_test.exs` is **red at HEAD `a0723bf6` independent of this
fix**: `defp castle_manufacture/2` (lines 301-302, committed in 160f23f2) is infinitely
self-recursive —

```elixir
defp castle_manufacture(intent, witness) do
  with_castle_lock(fn -> castle_manufacture(intent, witness) end)   # should call Xaas.Castle.Kernel.CLI.manufacture/2
end
```

— so every manufacture-based test deadlocks on its own file lock (13/19 tests ExUnit
60s-timeout inside `acquire_castle_lock`; reproduced solo, single-test, fresh lane-local
lock via `XAAS_CASTLE_TEST_LOCK`; lsof showed the test beam holding fd 88 on the lock while
sleeping on eexist — self-deadlock). The file is clean in the working tree (bug is in
commit 160f23f2). Not fixed here: file is outside this lane's write scope. Docketed for
the coordinator / a repair lane. Note: this also explains the W828-era "shared lock"
timeout noise under fan-out load.

## Falsifier / replay

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW863 \
  mix test test/xaas/castle_execute_court_test.exs
```

- Mutation: revert the two `to_string` compares to plain `!=` → the full-traversal court
  fails `REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH` (witnessed).
- If the GGEN contract override becomes a string, the jsonb round-trip proof test fails
  by design (guarding the compare-side placement).

## Standing vocabulary

- Compare-side normalization (both sites): **ALIVE** (court 10/10 x3)
- Full lawful Execute traversal → `:succeeded` sealed durable receipt + zero-row replay:
  **ALIVE** (was BLOCKED at HEAD per W828)
- Refusal courts (expired / foreign-witness / no-context): **ALIVE**
- `castle_refusal_negative_test.exs`: **BLOCKED pre-existing** (self-recursive
  `castle_manufacture/2`, lines 301-302) — repair lane needed
- `:castle_kernel` court with the real CASTLE binary: not run in this lane (same disclosed
  exclusion as W828)

## Lane lease

`_build-laneW863` — deletion attempted per the lane-lease law; see coordinator note below.
