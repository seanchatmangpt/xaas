# W984ip — unclaimed-family probe: Xaas.Actuation.Reactor undo/rollback arm

- Lane: W984ip, checkout `/Users/sac/xaas` @ branch `feat/playwright-surface` (3961c4ab at lane start)
- Court file: `test/xaas/actuation/reactor_undo_court_w984ip_test.exs` (new, 2 tests)
- Standing: ALIVE (witnessed, gates green)

## Subject

`Xaas.Actuation.Reactor` (`lib/xaas/actuation.ex:263-320`) and
`Xaas.Actuation.Kernel` — specifically the `undo: &Xaas.Actuation.Kernel.undo_actuate/3`
callback on the `:do` ash_step (actuation.ex:309), which Reactor invokes when `:do`
has succeeded but a later step (`:receipt`) fails and the run rolls back, and
`Xaas.Telemetry.OcelForwarder.forward_cancellation/1` it calls.

## Census and dispositions

| Branch | Prior coverage | Disposition |
|---|---|---|
|---|---| Chicago |
| `undo_actuate/3` cancellation clause (unit) | actuation_ocel_undo_test.exs | COVERED (pre-existing) |
| `undo_actuate/3` replay no-op clause (unit) | actuation_ocel_undo_test.exs | COVERED (pre-existing) |
| `forward_cancellation/1` envelope/no-URL arms | actuation_ocel_undo_test.exs, family_court_w984gj_test.exs | COVERED (pre-existing) |
| **Reactor-level undo wiring**: Reactor actually invokes undo on real rollback | none | **COURTED (this lane)** |
| **`run_reactor_or_rollback/2` `{:error,...} -> Ash.DataLayer.rollback` arm at reactor level** | none | **COURTED (this lane)** |
| **Post-rollback ledger cleanliness** (intent/receipt rows gone; key lawfully reusable) | none | **COURTED (this lane)** |
| Rollback of a real row mutation inside the failing run (mutating action + non-castable result) | none | NOT REACHABLE: every existing mutating action returns a record (`json_safe` -> map) which `:seal` accepts, so no existing action can fail `:receipt` after mutating. The enclosing `Ash.DataLayer.transaction` rollback mechanism is witnessed in the court via the intent/receipt rows (created by :admit inside the same transaction) being absent after the failed run. |
| `undo_actuate/3` at reactor level on a REPLAYED admission | unreachable: the replay path seals fine, so rollback-after-replay never occurs | COVERED at unit level (typed, no filler) |

## Court mechanism (zero mocks)

Real trigger found for "a step fails after `:do` succeeded": `Xaas.Accounts.Token`
`:is_revoked` — the one registry-admitted generic action that runs without external
services, mutates nothing, and returns a bare BOOLEAN. `json_safe/1` preserves
booleans, and the receipt's `:result` attribute is typed `:map`, so `Kernel.seal/2`'s
`Ash.update ... :seal` fails with a real `InvalidAttribute{field: :result, value: false}`
(observed verbatim in the Reactor.Audit error log), failing the `:receipt` step, firing
`undo_actuate/3` (non-replay clause) -> real HTTP cancellation event captured on a real
Bandit loopback server, and rolling the outer `Ash.DataLayer.transaction` back
(intent + receipt rows absent afterwards; same key then admits a fresh Provider
`actuate_status` as `replay? == false` and the Provider mutation lands).

`authorize?: false` is required on run/4 (Token policies forbid actor-nil otherwise);
that is the honest call context, not a bypass — the probe of the direct
`Ash.ActionInput` path with `authorize?: false` returned `{:ok, false}` first.

## Verification (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ip \
  mix test test/xaas/actuation/reactor_undo_court_w984ip_test.exs
Result: 2 passed

... mix test test/xaas/actuation_test.exs test/xaas/actuation_ocel_undo_test.exs test/xaas/actuation
Result: 80 passed, 7 excluded

Mock gate (scan_mock_usage(["test","lib"])): []
```

## Falsifier / boundary

- If `Kernel.seal/2` ever normalizes non-map results before the `:result` cast, the
  `:receipt`-failure trigger disappears; the court then honestly reports a failure and
  the arm needs a different trigger. That drift would be caught by this court.
- NOT done: no commit (per lane contract); lint/prestige not run.

## Cleanup

`rm -rf _build-laneW984ip`: attempted below.
