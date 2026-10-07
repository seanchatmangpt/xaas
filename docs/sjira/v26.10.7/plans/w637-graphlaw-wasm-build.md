# W637 — graphlaw WASM build receipt (Wasmex unification Phase 1)

Lane W637, v26.10.7 fleet seal. Date: 2026-10-07. Repo: `~/graphlaw` (canonical checkout, no worktree). Not committed, per directive.

## Subject

- `wasm/Cargo.toml` @ HEAD + [profile.wasm] merge (uncommitted working-tree edit, disclosed)
- Artifact: `/Users/sac/graphlaw/priv/graphlaw.wasm` (6,657,549 bytes)

## (1) FFI merge — NO-OP (already present, signature-exact)

`~/graphlaw/wasm/src/lib.rs` already exported exactly:

- `gl_alloc(len: u32) -> *mut u8`
- `gl_free(ptr: *mut u8, len: u32)` (unsafe extern "C")
- `gl_call(ptr: *mut u8, libm len: u32) -> u64`, returning `(out_ptr << 32) | out_len`

All existing statutory enforcement logic (N3, SHACL, policy admission) is routed through
`graphlaw::abi::call` inside `gl_call` — untouched, zero diff to `lib.rs`. The pack's
`ffi.rs`/`guards.rs`/`abi_meta.rs` were read as ground and NOT vendored: the in-tree FFI is
the same protocol wired directly to the hand-written safe core (`graphlaw::abi`) rather than
to generated `abi_meta` constants — structurally equivalent, protocol-identical (ABI 1,
16 MiB request limit, 256 MiB outstanding cap semantics present in both). No files copied
from the pack.

## (2) Cargo.toml merge

`cdylib` crate-type was already present. Added per
`wasi-json-abi-pack/generated/graphlaw/cargo-profile.toml`:

```toml
[profile.wasm]
inherits = "release"
opt-level = "s"
lto = true
codegen-units = 1
strip = true
panic = "abort"
```

Diff to `~/graphlaw/wasm/Cargo.toml`: exactly the `[profile.wasm]` table + a two-line
provenance comment. Final on-disk state re-verified after the edit.

## (3) WASI purity

Vendor patch preserved (`~/graphlaw/vendor/purrdf-sparql-eval` clock patch per
`vendor/README.md`; consumed via `features = ["abi", "wasi-patched-deps"]`). Purity
verified on the built binary: `strings graphlaw.wasm | grep -ci "js_sys\|wasm_bindgen"` → 0
matches. `file(1)`: "WebAssembly (wasm) binary module version 0x1 (MVP)"; magic
`00 61 73 6d 01 00 00 00` confirmed via xxd. Export names `gl_alloc`/`gl_call`/`gl_free`
present in the stripped binary (`strings -x` match). `wasm-objdump` not installed —
disclosed; file(1)+xxd+strings used instead.

## (4) Build + verification (real output)

```
cd ~/graphlaw/wasm
PATH=$HOME/.cargo/bin:$PATH CARGO_TARGET_DIR=target-laneW637 \
  cargo build --target wasm32-wasip1 --profile wasm
    Finished `wasm` profile [optimized] target(s) in 2m 25s   (exit 0)
```

- Artifact non-empty: 6,657,549 bytes.
- wasm-objdump: unavailable (disclosed); header verified via file(1) + xxd magic bytes.
- Digest (source artifact and installed copy identical):
  **sha256 `b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121`**
- Exports `gl_alloc`/`gl_call`/`gl_free` confirmed present by name in the binary.

## (5) Standing

**ALIVE (build-surface only)**: real compile under the pinned toolchain (1.96.0, rust-toolchain.toml), artifact on disk with digest, header verified, WASI-only imports (zero js_sys/wasm_bindgen strings), exports present by name. NOT yet witnessed: actual load/execute of `gl_call` through Wasmex/`wasmtime` — that is the next lane's falsifier (behavioral courts), out of scope for Phase 1. No commit made (directive); working tree carries the Cargo.toml edit + untracked `priv/`.

Cleanup: `target-laneW637` deleted after artifact extraction.
