# Seam-deploy receipt — graphlaw WASM leak fix + product-path wiring (lane xaas-seam-fix)

Lane `xaas-seam-fix`, 2026-10-08. Repo `/Users/sac/xaas` (canonical checkout, branch
`feat/playwright-surface`, base `7593a062`). Not pushed.

## Subject (exact)

- `lib/xaas/semantics/graphlaw_wasm.ex` (leak-window fix, real-WASI instantiation, public seams)
- `lib/xaas/semantics/graphlaw_pool.ex` (new singleton)
- `lib/xaas/bridges/graphlaw.ex` (dispatch wiring + engine digest provenance)
- `test/xaas/semantics/graphlaw_wasm_seam_test.exs` (new court, 8 legs)
- `docs/sjira/v26.10.7/plans/_GRAPHLAW_WASM_UNIFICATION_RECEIPT.md` (§4/§5 DRAFT flags cleared; tracked+clean, not mid-landing)
- `docs/sjira/v26.10.8/plans/seam-deploy.md` (this receipt)

## O/O*

- Prior-lane witness: `Xaas.Semantics.GraphlawWasm` = full PRD ABI, pin
  `fc23a292...aadcb38` verified, 8/8 courts (w638-wasmex-host.md) — but ZERO production
  callers: assess went `Xaas.Bridges.Graphlaw.assess/2` -> `AshGraphLaw.law/3` ->
  `AshGraphLaw.Pool` (dep vendored engine, digest `7bb2a7e5...6eee0`, measured on disk).
- W640 receipt finding (c): GraphlawWasm's zero-value WASI stubs TRAP on real
  op:"shacl" workloads; the W640 court runs on a real `Wasmex.Store.new_wasi/1` store.
- W638 disclosed gap: "no supervisor child spec added; transport only".

## mu/diff

1. **Leak-window fix** (`with_buffer/3`): a raise (or exit) out of `fun.(ptr)` previously
   propagated with the input buffer still allocated — only the returned
   `{:not_consumed,_}` path deallocated. Now rescue/catch safe-dealloc, then
   reraise/exit with the ORIGINAL payload, so the outer `guard/1` still classifies
   exits (`:call_timeout`/`:call_trapped`) unchanged. `{:consumed,_}` success path
   untouched (no double free; guest consumes input inside gl_call).
2. **Real-WASI instantiation** (same file, disclosed): `start/2` boots on
   `Wasmex.Store.new_wasi/1` (wasmex's native wasi_snapshot_preview1), retiring the
   zero-value stubs (W640 finding (c) trap class). Import judge unchanged; digest pin
   unchanged; `instantiation_imports/stub_body/zero_results/engine_new/admit` removed
   as dead. `with_input_buffer/3` + `artifact_path/0` exposed as court seams.
3. **`Xaas.Semantics.GraphlawPool`** (new): singleton GenServer; lazily boots ONE
   pinned instance from `priv/graphlaw.wasm` under the pin file; typed
   `Xaas.Actuation.Refusal` surfaces; `:call_trapped`/`:call_timeout`/`:abi_failure`
   recycle the instance; sticky start errors with `reset/0`. Serializing pool-of-one
   (disclosed: correctness over throughput). Lazily started — NOT added to
   `lib/xaas/application.ex` (outside this lane's file scope; disclosed to coordinator).
4. **Product-path wiring** (`Xaas.Bridges.Graphlaw`): server-less `assess/2` now
   dispatches `op:"law"` through GraphlawPool; fallback to `AshGraphLaw.law/3` ONLY on
   wasm transport failure; explicit `:server` keeps the legacy contract (the
   dead-server `:host_not_started` courts depend on it). `provenance.engine_sha256`
   names the engine that actually produced the verdict (pinned fc23a292 vs dep
   7bb2a7e5) — this is the transport discriminator the court asserts on.

## Courts (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneseamfix
mix test test/xaas/semantics/graphlaw_wasm_test.exs        # Result: 8 passed
mix test test/xaas/semantics/graphlaw_wasm_seam_test.exs   # Result: 8 passed
mix test test/xaas/chicago/bridges/graphlaw_test.exs \
        test/xaas/chicago/bridges/graphlaw_assess_deepening_test.exs \
        test/xaas/graphlaw_limit_gate_test.exs \
        test/xaas/graphlaw_limit_seams_test.exs            # Result: 35 passed
mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'
                                                           # => []
```

Seam-court legs: pool pin identity (info digest == pin file == byte digest), op
:"capabilities" through the pool, leak-fix raise leg, leak-fix exit leg, pinned-engine
admit (`provenance.engine_sha256 == fc23a292...`), pinned-engine refuse
(`:not_admitted`), poisoned-pin fallback discriminator (env pin poisoned -> legacy dep
pool verdict names `7bb2a7e5...`), legacy `:server` passthrough (`:host_not_started`).

## Verification ladder

narrow (mix compile, zero new warnings) -> unit (W638 court 8/8 unchanged after the
WASI-store change) -> integration (seam court 8/8 incl. both transport discriminators;
bridge courts 35 passed) -> mock gate []. Not run (out of lane scope): full mix test;
perf smoke (`:perf_smoke` tag-excluded; the 5s wasm watchdog default covers its shape).

## Standing

- Leak fix: ALIVE (exact subject, raise/exit legs witnessed on the real artifact).
- Product-path wiring: ALIVE (narrow) — real op:"law" assess through the pinned
  fc23a292 artifact with engine-digest-discriminated courts.
- Unification receipt §4/§5: DRAFT flags cleared from landed receipts.

## Falsifiers / open items

- Poisoned-pin court: a wrong Application-env pin forces the legacy fallback and the
  envelope names the dep engine — non-vacuous witness that legs 5-6 test the pinned
  transport, not the dep pool.
- Open (coordinator): supervision-tree child for `Xaas.Semantics.GraphlawPool`
  (lazy-start covers the current product path; tree wiring is application-owned).
- Open: `AshGraphLaw.Pool` remains the fallback engine; retirement (C14 one-kernel)
  is a future work order.

## Replay

```
cd /Users/sac/xaas && git log --oneline -3   # cfed243e, 26e3ced0 (base 7593a062)
shasum -a 256 priv/graphlaw.wasm             # fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38
shasum -a 256 /Users/sac/ash_graphlaw/priv/graphlaw/graphlaw.wasm  # 7bb2a7e5...
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneseamfix \
  mix test test/xaas/semantics/graphlaw_wasm_seam_test.exs
```
