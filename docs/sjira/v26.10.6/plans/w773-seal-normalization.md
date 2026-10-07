# W773 — Actuation seal-boundary error normalization

- **Lane**: W773, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface`, base HEAD `a0723bf6`. No commit (per dispatch).
- **Subject**: `lib/xaas/actuation.ex` (seal step ONLY),
  `test/xaas/actuation/run_idempotency_deepening_test.exs` (extended only),
  this receipt. Handwritten; no generator surface applies.
- **Standing**: ALIVE — 15/15 real-test pass on the exact working tree
  (10 deepening incl. the new W773 court + 5 pre-existing base courts,
  real sandboxed Postgres, real Reactor).

## Before (W747 gap 2, docs/sjira/v26.10.6/plans/w747-actuation-idempotency-deepening.md)

Execution errors shaped as tuples/atoms (`{:unknown_action, resource, action}`,
`{kind, reason}` catches, bare atoms) reached `Kernel.seal`'s `:failed` clause,
where `json_safe/1` rendered a tuple as a LIST. `ActuationReceipt.error` is a
`:map` attribute (actuation_receipt.ex:146), so the `Ash.update(..., action: :seal)`
failed `InvalidAttribute{field: :error, "is invalid"}`, the whole `:receipt`
reactor step failed, Reactor ran `undo_actuate/3` and the transaction rolled
back. The ledger stayed consistent (intent/receipt rows never persisted for the
failure) but the durable `:failed` record was never written — the sealed-:failed
path for tuple-shaped errors was effectively unreachable. `run/4` surfaced the
wrapped Reactor/Ash error envelope instead of the intent's typed failure.

## After (fix, minimal, seal boundary only)

`lib/xaas/actuation.ex` only — new private `sealed_error/1` in
`Xaas.Actuation.Kernel`, used in the `:failed` clause of `seal/2` in place of
the bare `json_safe(reason)`:

- maps pass through `json_safe/1` unchanged (success path, refusal path,
  and `:error` attribute type untouched);
- tuples/atoms (whose `json_safe` rendering is a list/scalar) become the
  W707 gymact-seal-fix map idiom: `%{"class" => <first element>,
  "detail" => <rest, json-safe>}`; a scalar falls back to
  `%{"class" => "execution_error", "detail" => ...}`;
- the envelope's `:error` still carries the RAW `reason` — the surfaced
  caller contract of `run/4` is now `{:error, {:unknown_action, ...}}`
  (the typed tuple, previously masked by the roll-back error envelope).

## Regression court (extended deepening test, W747's 9 courts kept)

- `(f) W773`: run/4 with a nonexistent action atom → `execute_action/8`
  returns the raw `{:unknown_action, Provider, :does_not_exist}` tuple →
  asserts the real persisted rows: `ActuationReceipt` `:failed` with
  `error == %{"class" => "unknown_action", "detail" => ["Elixir.Xaas.Marketplace.Provider", "does_not_exist"]}`
  and a `completed_at`; `ActuationIntent` terminal `:failed`. No rollback:
  rows survive the sandbox transaction.

## Mutation rationale

Drop `sealed_error/1` (revert to bare `json_safe(reason)`): the tuple
renders as a list, the `:seal` `Ash.update` rejects the `:error` map
attribute, the reactor `:receipt` step fails, the transaction rolls back —
killed by the persisted-row asserts in (f): the receipt `find` returns nil
(`assert %ActuationReceipt{status: :failed, ...} = receipt` fails on nil)
AND `assert {:error, {:unknown_action, ...}} = ...` fails (run/4 returns
the wrapped `{:error, {:reactor_failed, ...}}` envelope instead). Double kill.

## Green tails (real output)

```
$ cd /Users/sac/xaas
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW773 \
    mix test test/xaas/actuation/run_idempotency_deepening_test.exs test/xaas/actuation_test.exs
Finished in 1.2 seconds (1.2s async, 0.00s sync)
Result: 15 passed
```

(10 deepening — W747's 9 incl. the d3 raw FunctionClauseError boundary,
unchanged and green — plus the new (f) court; 5 pre-existing base courts.)

## Transport failures

- Fresh lane build root forced a full ~20 min compile; first run was moved
  to background and its `tail -8` truncated the failure detail. Rerun of the
  single court exposed the only defect: the test asserted
  `"Xaas.Marketplace.Provider"` but the persisted detail string is
  `"Elixir.Xaas.Marketplace.Provider"` (raw module atom stringified). Test-side
  assertion corrected; lib fix unchanged.
- Note: `lib/xaas/actuation.ex` carries a concurrent lane W780's edit
  (`admit_authority` struct-guard, `:claim_shaped_authority_refused`) in the
  same working tree — orthogonal to this lane's seal hunks, left untouched.

## Replay / environment

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW773 \
  mix test test/xaas/actuation/run_idempotency_deepening_test.exs test/xaas/actuation_test.exs
```

Local Postgres (sandbox) required. Success path, authority validations, and
the `ActuationReceipt :error` `:map` attribute type unchanged.

## Cleanup

`_build-laneW773` deleted after final green run (lane lease law).
