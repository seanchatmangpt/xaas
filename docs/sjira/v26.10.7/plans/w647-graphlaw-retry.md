# W647 — graphlaw adoption retry of rust-wasi-wasmex-pack (W641c unblock)

**Standing: ALIVE** — generated FFI shell landed contract-identical, wasm rebuilt,
digest rotation disclosed, tests green, pushed ff.

- Subject: ~/graphlaw @ graphlaw-registry-limits, commit `918dda2`
  ("feat(wasm): W647 generated FFI shell via rust-wasi-wasmex-pack (W641c unblock)"),
  parent `1869a16` (W637b). Pushed: new remote branch `graphlaw-registry-limits`
  (first push = fast-forward by construction; local HEAD == origin HEAD).
- Actuator: ggen 26.9.28; cargo 1.96.0; target wasm32-wasip1 installed.
- Unblocks: W641c BLOCKED(integration-design-needed).

## Landing

| file | status |
|---|---|
| ontologies/graphlaw-wasm.ttl | new; wja: instance graph restating the verified ABI facts from src/abi.rs, wasm/src/lib.rs, src/registry.rs (gl prefix, 16 MiB / 64 / 256 MiB, vec buffers, packed-u64, call-consumes, no abi-version export, 14 ops + 9 refusal codes in wire order) |
| ggen.toml | + [[packs]] rust-wasi-wasmex-pack (path ../ggen-marketplace/packs/rust-wasi-wasmex-pack) + wasm-abi-meta / wasm-ffi rules -> wasm/src/{abi_meta.rs,ffi.rs}; + ontology import |
| wasm/src/abi_meta.rs | generated; ABI_VERSION 1, MAX_REQUEST_BYTES 16777216, MAX_OUTSTANDING_BYTES 268435456, OPS (14), ERROR_CODES (9) |
| wasm/src/ffi.rs | generated; the FFI shell |
| wasm/src/lib.rs | hand-written module shell: doc, `pub mod {abi_meta,ffi}`, compile-time const-asserts pinning rendered limits to graphlaw::abi, native contract tests |
| priv/graphlaw.wasm.sha256 | DISCLOSED DIGEST ROTATION (below) |

## Contract-identity analysis (falsifier of the STOP condition)

Generated wasm/src/ffi.rs vs the verified hand-written shell it replaced
(W641c conflict table, all four rows resolved by W642 parameters):

| # | W641c conflict | resolution in the landing |
|---|---|---|
| 1 | template local limit consts vs graphlaw::abi | limits render from the graph into abi_meta.rs (16777216 / 268435456); wasm/src/lib.rs const-asserts `abi_meta::MAX_REQUEST_BYTES == graphlaw::abi::MAX_REQUEST_BYTES`, `MAX_OUTSTANDING_BYTES == MAX_OUTSTANDING_ALLOC_BYTES`, `MAX_JSON_DEPTH`, `ABI_VERSION` — mismatch = compile error, so graphlaw::abi stays the single source of truth |
| 2 | crate::handle_request invention | rendered call sites are `graphlaw::abi::{call,missing_buffer_response,limit_response}` directly (abi_path="graphlaw::abi", call_hook="call"); a `shell_routes_through_graphlaw_abi` native test asserts call_buf(null) == missing_buffer_response() and call_buf(dangling, u32::MAX) == limit_response("request_bytes", …) byte-for-byte |
| 3 | crate-local missing/limit hooks | same as #2 — routed to graphlaw::abi, asserted in test |
| 4 | b"{}" empty-response substitution | policy = "substitute-empty-object" (the pack's only sound value; any other value compile_error!s in the generated crate). The branch is dead code: graphlaw::abi always returns a JSON object. In-tree code had no such branch; on this input domain the two are behaviorally identical, and the native test asserts responses are non-empty |

Export surface: gl_alloc(u32)->*mut u8, gl_free(*mut u8,u32), gl_call(*mut u8,u32)->u64,
`#[no_mangle] extern "C"` — signatures identical; no gl_abi_version export in-tree or
generated (hasAbiVersionExport=false). Allocation discipline identical (Vec capacity
len.max(1), response shrink_to_fit, Vec::from_raw_parts(ptr,len,len.max(1)) reconstruction,
fetch_update outstanding accounting; the generated reserve uses checked_add where the old
code used `n + held` — strictly safer, same defined behavior).

## Digest rotation (disclosed, not silent)

- old: b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121 (6,657,549 bytes) — W637b pin
- new: fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38 (6,657,708 bytes)
- Rebuild expected: module structure changed (lib.rs restructure + generated shell),
  bytes differ; sidecar updated in the same commit, never silently.

## Verification (real output)

- `ggen graph validate --files ontologies/graphlaw-wasm.ttl` → 108 quads, clean
- `ggen sync run` → exit 0; abi_meta.rs + ffi.rs written; chicago court tests re-rendered
  with template formatting churn — reverted to HEAD (out of lane scope; disclosed:
  the chicago_court.rs.tmpl template renders non-rustfmt'd output vs the committed
  rustfmt'd files — a pre-existing template formatting drift, not this lane's diff)
- `cargo test -p graphlaw-wasm` → **6 passed; 0 failed**
- `cargo build --target wasm32-wasip1 --profile wasm -p graphlaw-wasm` → exit 0 (1m02s)
- `shasum -a 256 priv/graphlaw.wasm` → fc23a292…; sidecar rewritten to match
- `git push -u origin graphlaw-registry-limits` → new branch, exit 0; tracking clean

## Standing / open edges

- ALIVE: the wasm module surface is now graph→ggen→projection with graphlaw::abi as
  the pinned single source of truth (compile-time) and registry.rs (test-time).
- NOT in this lane: affidavit consumer landing (W642 open edge); pack-side formatting
  drift of chicago_court.rs.tmpl output (pre-existing); `cargo test` for the full
  workspace not run (src/ untouched; wasm crate tests are the lane boundary).
- Falsifier used: "generated FFI not contract-identical ⇒ typed BLOCKED" — not
  triggered; every W641c row resolved by parameterization + pinned equality.
