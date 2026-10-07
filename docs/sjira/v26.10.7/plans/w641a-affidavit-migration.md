# W641a — affidavit wasi-json-abi-pack → rust-wasi-wasmex-pack migration

**Standing: BLOCKED(pack-contract-divergence)** — no half-states committed; `~/affidavit` tree restored byte-identical to HEAD (`1056fc695b621ca1b869cefb44e789db99bb88ac`, branch `feat/advanced-witness-capability-set`, ahead 20).

## Grounding (reality-to-reality, before any edit)

Directive's example mapping vs. reality:

| directive | reality on disk |
|---|---|
| old names `wasm_ffi.rs.tmpl`, `wasm_cargo_config.toml.tmpl` | confirmed (`~/ggen-marketplace/packs/wasi-json-abi-pack/templates/`) |
| new pack `templates/guest/`: `cargo_config.toml.tmpl`, `Cargo.toml.tmpl`, `ffi.rs.tmpl` | confirmed |
| name-swap migration possible | **false** — contract divergence below |

Actual divergence (`~/ggen-marketplace/packs/rust-wasi-wasmex-pack/`):

1. **No `queries/` directory and no `package.toml`** — only `pack.toml` (which lists
   `deprecated_precursors = ["wasi-json-abi-pack", "beam-wasmex-host-pack"]` but declares
   no named outputs). All six `wasi` rules in `~/affidavit/ggen.toml` resolve queries via
   `query = { pack = ..., output = "queries", file = ... }` → unresolvable.
2. **Only 3 guest templates exist** (`guest/ffi.rs.tmpl`, `guest/cargo_config.toml.tmpl`,
   `guest/Cargo.toml.tmpl`). Four of six rendered surfaces have no counterpart:
   `abi_meta.rs`, `capability-registry.json`, `op-examples.json`, `ARTIFACTS.sha256`
   (the last is mode `Create` — a registry pin; dropping it is a semantic regression).
   Host/test templates (`host/*`, `test/*`) are Elixir-side and irrelevant to this guest crate.
3. **Variable contract diverges**: old templates consume flat `crate_name`, `export_prefix`,
   `abi_version`, `stack_size_bytes`, `imports_policy`; new guest templates consume
   `guest.crate_name`, `prefix`, `max_request_bytes`, `guest.max_outstanding_bytes`
   (and hard-code stack size 4 MiB vs affidavit's ontology-driven 16 MiB
   `affidavit-wasm/.cargo/config.toml`). Even the two "mappable" rules would need
   consumer-local queries rewritten to a nested `guest.*` row shape — invention, not mapping.
4. `guest/Cargo.toml.tmpl` would render `affidavit-wasm/Cargo.toml`, clobbering the
   hand-written workspace manifest — structural change by construction.

## Executed steps (real tails)

1. **Baseline sync, unmodified manifest** (ggen 26.9.28, exit 0): tree was clean at start;
   baseline `ggen sync run` drifted **18 files** (e.g. `src/crypto_trust_verify.rs` −332 lines,
   `affidavit-wasm/registry/op-examples.json` chain_hash `199d1e6a…` → `d6cd5e0c…`,
   `ARTIFACTS.sha256` notably NOT rewritten). i.e. the checkout is stale vs. current sibling
   pack contents — independent of my lane. All reverted (`git checkout -- .ggen-v2 affidavit-wasm benches src tests`).
2. **Trial migration edit** (pack name/path swap + the two existing new-template refs),
   `ggen sync run` → typed failure:
   ```
   ERROR: CLI execution failed: Command execution failed: validation error:
   [FM-GEN-005] rule `wasm-ffi`: query file `…/packs/rust-wasi-wasmex-pack/queries/ffi.rq`
   (pack `rust-wasi-wasmex-pack`, output `queries`) unreadable: No such file or directory (os error 2)
   ```
3. **Reverted** — `git status --short` clean (only pre-existing untracked `mutants.out*`),
   `diff -q ggen.toml` vs backup: identical to HEAD.
4. `cargo build --target wasm32-wasip1` not run — no migrated subject exists to build.

## What unblocks (operator decision)

- New pack grows `queries/` (or `package.toml` named outputs) covering the 6 rule surfaces,
  with a variable contract the affidavit ontology can satisfy; or
- Affidavit ships consumer-local queries emitting the `guest.*` row shape and the four
  unmapped surfaces get explicit retire/re-home decisions (registry pin especially);
- The baseline 18-file sync drift (trust-plane + op-examples) needs its own lane — it is a
  pre-existing pack-vs-checkout staleness, not a migration artifact.

Falsifier for a retry: `ggen sync run` with the migrated manifest exits 0 AND
`git diff affidavit-wasm/` shows zero structural change AND `ARTIFACTS.sha256` unchanged.
