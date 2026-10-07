# W641b — ferroplan wasi-json-abi-pack → rust-wasi-wasmex-pack migration

Standing: **BLOCKED(pack-capability-missing)** — migration NOT executed; ggen.toml untouched; no commit, no push.

## Grounding (executed 2026-10-07)

Old pack `~/ggen-marketplace/packs/wasi-json-abi-pack` — the three registry generation rules in
`~/ferroplan/ggen.toml` (lines ~19-45) consume:
- queries: `queries/registry.rq`, `queries/examples.rq`, `queries/artifacts.rq`
- templates: `templates/wasm_capability_registry.json.tmpl`, `templates/wasm_op_examples.json.tmpl`, `templates/wasm_artifacts.sha256.tmpl`
- outputs: `crates/ferroplan-wasm/registry/{capability-registry.json,op-examples.json,ARTIFACTS.sha256}`

New pack `~/ggen-marketplace/packs/rust-wasi-wasmex-pack` — full tree listed:
`fixtures/probe_eval.ttl`, `ontology.ttl`, `pack.toml`, `README.md`, `shapes/rww.shacl.ttl`,
`templates/guest/{cargo_config.toml.tmpl,Cargo.toml.tmpl,ffi.rs.tmpl}`,
`templates/host/{mix_deps.exs.tmpl,wasm_host.ex.tmpl,wasmex_host_manifest.json.tmpl}`,
`templates/test/wasm_host_court.exs.tmpl`.

**No `queries/` directory exists in the new pack.** Grep across the pack for `registry`/`.rq`
returns zero hits. The only JSON-emitting template, `wasmex_host_manifest.json.tmpl`, is a
static Tera manifest rendered from config variables (host.artifact_path, prefix, limits) — not a
SPARQL-query projection of the consumer ontology, and has no equivalent for
`capability-registry.json`, `op-examples.json`, or `ARTIFACTS.sha256`. `pack.toml` confirms the
supersession claim (`deprecated_precursors`), but the new pack does not carry the registry
projection capability forward — it is a Rust-guest/Elixir-host pipeline scaffolding pack.

## Falsifier for unblocking

The migration becomes executable when rust-wasi-wasmex-pack ships registry-equivalent
generation inputs: `queries/{registry,examples,artifacts}.rq` (or a documented query-output
naming) plus registry/op-examples/artifacts templates whose rendered output is byte-identical to
`crates/ferroplan-wasm/registry/*` under the same ontology. Until then, forcing the [packs]
stanza swap would break `ggen sync run` (missing query/template references) — refused per
directive.

## Commands (real)

- `cat ~/ferroplan/ggen.toml` — read; [packs] + 3 wasm generation rules identified
- `find` both pack trees (full listing above, in session log)
- `grep -ril 'registry\|\.rq' rust-wasi-wasmex-pack/` — **zero hits**
- `head README.md`, `cat pack.toml` — supersession confirmed, capability absent

No edit/sync/commit/push performed in ~/ferroplan. ferroplan working tree left as found
(pre-existing dirty state: `.ggen-v2` receipts, `lib.rs`, untracked wasm/reachability files —
not mine, not touched).
