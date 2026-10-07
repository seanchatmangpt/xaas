# W45 — ferroplan wasm artifact pin (v26.10.6 wave-2)

Lane: W45. Date: 2026-10-06. Repo: `~/ferroplan` @ `c037876` (main, HEAD unchanged).
Scope held: artifact + pin + receipt only. No source edits, no git mutations
(no commit — artifact left staged-ready as untracked file for coordinator).

## What was done

1. Built the wasm via the repo's own build path (wasm32 targets already
   installed; no rustup setup needed):
   `cargo build --locked -p ferroplan-wasm --release --target wasm32-wasip1`
   → Finished release in 51.68s. (Note: `registry/ARTIFACTS.sha256`'s comment
   says `--profile wasm`, but no `[profile.wasm]` exists in the workspace
   `Cargo.toml` — `--release` is the real profile that reproduces the pin.)
2. Placed the artifact at the repo's conventional location, beside its pin:
   `/Users/sac/ferroplan/crates/ferroplan-wasm/registry/ferroplan_wasm.wasm`
   (3,521,589 bytes; not gitignored — verified with `git check-ignore`, exit 1).
3. No new pin file was created. R6's named convention
   (`registry/ARTIFACTS.sha256` + `wja:wasmSha256`/`wja:wasmBytes` in
   `ontology/ferroplan-wasm.ttl`) already carries a real digest, and the fresh
   build reproduced it **byte-identically**:
   `088d9c3b0306e36123ddc1ee780ad7e9d4bd2ebb54f9726c43f40a2f6d718233`,
   3,521,589 bytes. Adding a second pin file would have drifted from the
   ontology-enforced single-source pin (the `pin_drift` court refuses any
   second wasm line). The artifact was the only missing piece.

## Verification (real output)

- `file`: `WebAssembly (wasm) binary module version 0x1 (MVP)`.
- sha256 of placed artifact == registry pin == ontology pin (above).
- Loadability/execution: the crate's own WASI court run in-loop under a real
  runner (`CARGO_TARGET_WASM32_WASIP1_RUNNER=wasmtime`):
  `cargo test -p ferroplan-wasm --target wasm32-wasip1 --release --lib`
  → **54 passed; 0 failed; 1 ignored** (wasi_abi solve/replan/repair suite).
  First attempt without the runner env var failed (exit 126, no wasm handler
  on this host) — the runner was required, recorded honestly.
- Pin consistency: `cargo test -p ferroplan-wasm --test pin_drift` →
  **7 passed; 0 failed** (registry pin == ontology pin, mutation-refusal courts).
- Final `git status`: only `?? crates/ferroplan-wasm/registry/ferroplan_wasm.wasm`
  added; the 4 pre-existing dirty ggen receipt files untouched.

## Receipt fields

- Subject: `~/ferroplan` @ `c03787687da4c0cd7d11d2f8b1bf1a9851ef8758` + one new
  untracked file `crates/ferroplan-wasm/registry/ferroplan_wasm.wasm`.
- Artifact digest: sha256 `088d9c3b0306e36123ddc1ee780ad7e9d4bd2ebb54f9726c43f40a2f6d718233`,
  3,521,589 bytes.
- Generated-vs-handwritten: artifact is a real `cargo` build product of the
  pinned source; no generated file hand-edited.
- Standing: **ALIVE** for "pinned, reproducible, loadable wasm artifact at the
  repo's conventional path" — verified by byte-identical rebuild + wasmtime
  test execution + pin courts. Downstream R6 hops (xaas bridge vendoring,
  pplan provider, ash_surface binding) are now unblocked at this digest.
- Falsifier status: reproduction is the falsifier — any source change shifts
  the digest and `pin_drift`/`assert_pin` refuses the stale pin (by design;
  per ARTIFACTS.sha256 comments the ggen harness rebuilds and panics on drift).
- Open for coordinator: `git add crates/ferroplan-wasm/registry/ferroplan_wasm.wasm`
  + commit at integration (lane rules: no git mutations from this lane).
