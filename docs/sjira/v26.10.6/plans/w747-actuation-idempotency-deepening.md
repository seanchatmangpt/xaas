# W747 — Actuation run/4 Idempotency/Replay Deepening

Lane: W747, xaas v26.10.6 campaign, branch `feat/playwright-surface` (HEAD a0723bf6).
Subject: `test/xaas/actuation/run_idempotency_deepening_test.exs` (new, uncommitted, lane-written).

## What was built

Chicago-style deepening of the `Xaas.Actuation.run/4` idempotency/replay contract
(`lib/xaas/actuation.ex`), 9 tests, zero mocks, real Postgres sandbox, real Ash
resources + real Reactor. `:actuate_status` exercised only through the admitted
`Xaas.Actuation.run/4` DO path (plus the pre-existing bypass refusal idiom).

- (a) same key twice → second envelope `:replayed`, `replay?` true, same
  `receipt.id`/`intent.id`; exactly 1 ActuationIntent and 1 ActuationReceipt row
  per key persisted.
- (a2) replay carries the original consequence state: subject row still holds
  first run's status; replay receipt `result_hash`/`result` equal the first
  receipt's — replay reads durable receipt state, not a re-executed mutation.
- (b) two different keys for equivalent intents → two real receipts, two
  intents, no dedup (both envelopes `:succeeded`, `replay?` false).
- (c) replay after process restart: `Task.async` + real
  `Ecto.Adapters.SQL.Sandbox.allow(Xaas.Repo, parent, task.pid)`; the fresh
  process gets a replay on the same key, same receipt/intent ids.
- (d1) missing `:idempotency_key` → `{:error, :idempotency_key_required}`;
  zero intents persisted.
- (d2) `authorize?: false` with empty `authority: %{}` → refusal via the
  `:admit` step, transaction rolls back, zero intent/receipt rows.
- (d3) malformed intent fields (string action, non-map input) rejected at the
  `run/4` guard boundary with `FunctionClauseError`; nothing admitted.
- (d4) intent forced back to `:executing` (interrupted-run simulation) →
  `{:error, {:idempotency_not_replayable, key, :executing}}` — the
  transactional path has no resume semantics (that is the external
  three-commit protocol's `:resumed?` path).
- (e) determinism ×2: two full succeed-then-replay cycles give identical
  envelope shape and identical receipt `input_hash`/`result_hash`.

## Commands / exits (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW747 \
  mix test test/xaas/actuation/run_idempotency_deepening_test.exs
  → exit=0 … "Result: 9 passed"   (earlier runs logged; final run /tmp/w747_run2.log)

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW747 \
  mix test test/xaas/actuation_test.exs
  → "Result: 5 passed"   (pre-existing suite, no regression)
```

## Standing

- New file: ALIVE (9/9 on exact subject, real gates).
- Pre-existing `test/xaas/actuation_test.exs`: 5/5, ALIVE, unchanged behavior.
- Type-safety regressions: none (determinism hashes identical across cycles).

## Typed gaps (observed, not repaired in this lane)

1. `unwrap_reactor_error/1` in `lib/xaas/actuation.ex` surfaces only
   `{:idempotency_conflict, _}` and `{:idempotency_not_replayable, _, _}`
   raw; the admission-court atom `:delegated_actuation_requires_authority_evidence`
   arrives wrapped as `{:reactor_failed, %Reactor.Error.Invalid{errors:
   [%Reactor.Error.Invalid.RunStepError{error: :...}]}}`. Typed refusal
   delivered, but not in the flat shape callers of the two idempotency
   errors get — asymmetric error-surface contract. (Tested as-observed in d2.)
2. Execution errors sealed as `:failed` (e.g. `{:unknown_action, ...}`) are
   double-wrapped on the way out (`Ash.Error.Invalid` inside `RunStepError`
   inside `{:reactor_failed, ...}`) because the `:receipt` step itself fails
   to persist the tuple-shaped error into `ActuationReceipt.error` — the
   receipt `:error` attribute rejects the 3-tuple shape, so the typed seal
   fails and the reactor error replaces it. The receipt row is never sealed
   `:failed` for these; the intent stays `:executing` and is rolled back with
   the transaction, so the durable ledger is consistent, but the sealed-:failed
   path for tuple-shaped errors is effectively unreachable. This lane asserts
   the guard-boundary behavior (`FunctionClauseError`) instead of the
   unreachable `{:unknown_action, ...}` return shape.

## Transport failures

- Two early compile attempts failed with a SyntaxError in `lib/xaas/ocel.ex:36`
  from a concurrent lane's in-flight edit on the shared canonical checkout;
  resolved by that lane (file now `:: %{`, mtime 2026-10-07 03:04:25). Not a
  defect of this lane's subject.
- `Ecto.Adapters.SQL.Sandbox.allow/2` → corrected to `allow/3`
  `(repo, parent, allow)` per installed ecto_sql 3.14.

## Cleanup

`_build-laneW747` deleted after final green run (lane lease law). No commits
made; the only tree change is the new test file + this receipt.
