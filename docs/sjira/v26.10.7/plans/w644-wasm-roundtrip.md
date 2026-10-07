# W644 — graphlaw.wasm load-leg witness (W638 unblock)

Lane: W644, fleet seal v26.10.7. Repo: /Users/sac/xaas. Date: 2026-10-07.
No commit (per lane order). Standing: **ALIVE (load-leg)** — probe test 4/4 passed on two
fresh runs, real gl_call verdicts returned through the packed-u64 path.

## Artifact identity (verified on copy)

| field | value |
|---|---|
| source | ~/graphlaw/priv/graphlaw.wasm |
| copied to | /Users/sac/xaas/priv/graphlaw.wasm |
| bytes | 6,657,549 (verified post-copy via wc -c and File.stat in test) |
| sha256 | b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121 |
| sidecar | /Users/sac/xaas/priv/graphlaw.wasm.sha256 (written) |

## Module surface (observed, not inferred — Wasmex.Module.imports/exports on the compiled module)

- Imports: WASI-only, exactly 7:
  `wasi_snapshot_preview1.{clock_time_get, environ_get, environ_sizes_get, fd_write, proc_exit, random_get, sched_yield}`.
  **No non-WASI imports. No initialize/reactor init export.** Stubs returning 0 suffice
  (proc_exit returns nothing; never invoked in our runs).
- Exports: `gl_alloc, gl_call, gl_free, memory` (plus wasm-bindgen internals:
  `__wbindgen_malloc/realloc/free`, externref table helpers, `__abort_handler`,
  `__instance_terminated`, `__wbindgen_exn_store`, jspi helpers).

## Call contract (witnessed)

`gl_call(in_ptr, in_len) -> packed u64 = (out_ptr <<< 32) | out_len` — confirmed by two real
executions (packed values decoded to valid (ptr, len) that read back valid UTF-8 JSON).

## First real gl_call results

Run: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW644 mix run` (fresh instance):
- `{"op":"capabilities"}` (21 B in) → packed=74837159432946975, out_len=1311,
  `"ok":true, "crate":"26.10.5"`, ops: capabilities/sniff/parse/convert/canonical/sparql/
  shacl/shex/n3/entail/datalog/hooks/law/policy; registry_sha256
  sha256:9bdaedd8a284e5187bd14f18251c57193809a73cf4c337093c241981e71a60d6;
  surface_sha256 sha256:fcee74ee068940f9e9879ccd41371807f469d63950c8f63b095117391dbc8e28
- `{"op":"sniff","text":"@prefix e: <https://e/> . e:s e:p e:o ."}` (63 B in) → out_len=48,
  `{"dialect":"Turtle","engine":"PurRdf","ok":true}`

gl_free succeeded on both input and output buffers (returned `{:ok, _}` — no trap).

## Test

`test/xaas/semantics/graphlaw_wasm_load_test.exs` (4 tests, Wasmex 0.15.1 per mix.lock):
digest pin, import/export surface, and two gl_call probes. Wasmex directly per lane order;
W638's files untouched.

Commands (both runs):
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW644 mix test test/xaas/semantics/graphlaw_wasm_load_test.exs`
→ `4 tests, 4 passed` (run 1 seed 564851-ish, 2.7s; run 2, 2.6s). Both fresh process roots.

## For W638 (host adapter) and W640

- No BLOCKED import surface: WASI-only, satisfiable with 7 zero-return stubs — the host pack
  `wasi_only` import mode applies as-is.
- No `initialize` export → host pack's init invocation is skipped (empty init_rows path).
- out_mode = `packed_u64`. alloc/free/dealloc all map to `gl_alloc`/`g_free`/`gl_free` — note:
  the host template has separate alloc/free/dealloc export slots; graphlaw provides only
  gl_alloc/gl_free, so dealloc and free BOTH bind `gl_free` (single free function for both
  input and output buffers — witnessed working).
- Use the `capabilities` op as the cheapest liveness probe; `sniff` as the cheapest
  semantic op.

## Standing

ALIVE (load-leg witnessed). Not yet: statutory W638 round-trip (receipt discipline, digest
pinning through a generated host module, replay export — graphlaw exposes NO replay export,
so W638 must run without the template's replay pair or bind it to a wrapper).