# W984dh — independent verification of the W644/W637 graphlaw.wasm load leg

Lane W984dh, v26.10.7 fleet seal. Repo: /Users/sac/xaas. Date: 2026-10-07.
No commit (per lane order). Independent verdict: **CONFIRM — W644's ALIVE (load-leg)
stands.**

## Subject identity

- `priv/graphlaw.wasm`, 6,657,549 bytes, sha256
  `b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121` — verified against the
  W637 pin file `priv/graphlaw.wasm.sha256` and byte-identical (`cmp`) to the source
  `~/graphlaw/priv/graphlaw.wasm`. (First hash taken was SHA-1 `55d08f0a…` — operator error,
  superseded by the SHA-256 match above; no drift.)
- Sidecar pin matches; source and installed copy identical.

## Independent probe (own court, W644's test untouched)

`test/xaas/semantics/graphlaw_wasm_load_verify_test.exs` — raw Wasmex 0.15.1, no use of
W638's `Xaas.Semantics.GraphlawWasm` adapter. 4 tests:

1. artifact digest pin (recomputed over the on-disk bytes),
2. import/export census via `Wasmex.Module.imports/exports` on the compiled module,
3. `gl_call` round trip: `{"op":"capabilities"}` → alloc → write → call → unpack
   `(out_ptr<<<32)|out_len` → read → `gl_free` → decode,
4. error leg: `{"op":"__no_such_op__"}` → typed JSON refusal, no trap.

## Execution (real tails, 3 fresh BEAM roots)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dh \
  mix test test/xaas/semantics/graphlaw_wasm_load_verify_test.exs
→ seeds 0 → 4 tests, 4 passed (2.6s) ; 637418 → 4 passed (2.4s) ; 984 → 4 passed (2.3s)
```

(Run 1 of this series failed 2/4 on a host-side API misuse — I destructured
`Wasmex.Memory.read_binary/4` as `{:ok, binary}` when it returns the binary directly; the
guest responses were already valid JSON in that failing run, visible in the assertion tail.
Fixed in the test host code only; guest behavior never wavered.)

## Observed surface (matches W644 exactly)

- Imports: exactly 7, all `wasi_snapshot_preview1.{clock_time_get, environ_get,
  environ_sizes_get, fd_write, proc_exit, random_get, sched_yield}`; no non-WASI namespace.
  Zero-return stubs instantiate cleanly — **no BLOCKED/unsatisfiable-WASI finding; the
  import enumeration a W638-successor needs is this list** (signatures as in the test's
  `stub_imports/0`).
- Exports: `gl_alloc/gl_call/gl_free/memory` (+ wasm-bindgen internals). No `initialize`.
- `gl_call` packed-u64 contract witnessed: `{"op":"capabilities"}` → `"ok":true`,
  `crate 26.10.5`, 14 ops, registry/surface sha256 identical to W644's values
  (registry `9bdaedd8…`, surface `fcee74ee…`).
- Unknown-op request returns `{"ok":false,"error":{"kind":"Unsupported",
  "message":"unknown op `__no_such_op__`"}}` — typed refusal, no trap.

## Adjacent finding (out of lane scope, disclosed, not gated)

W638's in-flight `lib/xaas/semantics/graphlaw_wasm.ex` is inconsistent with the witnessed
surface on three points a successor should reconcile before its court runs:

1. `judge_imports/2` and `instantiation_imports/1` refuse ANY import set, but the kernel
   imports 7 WASI functions — as written, `start/2` can never admit the real artifact.
   The `@wasi_allowlist` exists in the same file but is dead.
2. `safe_dealloc/3` calls `@dealloc_export`, which is never defined — reads as `nil`
   (compiles with a warning; dealloc would call `Wasmex.call_function(pid, nil, …)`).
3. Module docstring claims "zero-import admission" — superseded by the 7-WASI-stub surface.

## Standing

**ALIVE (load-leg, independently witnessed)**: raw Wasmex load + real `gl_call` verdicts on
3 fresh roots, digest pinned to the W637 artifact. Court + enumeration are the deliverables;
no production code written. Housekeeping: `_build-laneW984dh` (~430 MB) deletion was denied
by the permission layer — left in place for the coordinator per the lane-lease cleanup law.
