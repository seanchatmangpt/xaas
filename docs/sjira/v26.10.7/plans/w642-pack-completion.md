# W642 — rust-wasi-wasmex-pack completion (W641a unblock lane)

**Standing: PARTIAL_ALIVE** — pack completed, validated, falsifier executed on the real
consumer; consumer manifest landing is the affidavit lane's decision; push withheld
(foreign unpushed commits on the branch).

- Pack commit: `5fc3e96fd` on `feat/aaif-gcp-roadmap-v26.10.5` (~/ggen-marketplace)
- Consumer subject: ~/affidavit @ `1056fc6` (branch `feat/advanced-witness-capability-set`, ahead 20), tree restored clean after trial
- Actuator: ggen 26.9.28

## Grounding

W641a receipt divergence table + old pack full surface read before authoring:
`queries/{ffi,meta,cargo,registry,examples}.rq`, templates `wasm_abi_meta.rs`,
`wasm_capability_registry.json`, `wasm_op_examples.json`, `wasm_artifacts.sha256`,
`wasm_cargo_config.toml`, `wasm_ffi.rs` (381 lines); `package.toml` outputs mechanism.
New pack contract mapped from `ontology.ttl` + `shapes/rww.shacl.ttl` (rww: PipelineBinding /
GuestRustCrate / HostElixirModule vocabulary; guest.* template variables).

**Ontology-gap check (directive's BLOCKED condition — not triggered).** The new pack's
ontology lacked the *vocabulary* (schema layer) the old queries select, not the *facts*:
the facts are instance assertions that live in the consumer graph
(~/affidavit/ontology/affi-wasm.ttl, wja: vocabulary) and already exist on disk. Gap
closed by authoring the vocabulary succession section into the pack ontology (schema
layer only, rdfs:seeAlso alignment to rww: counterparts; `wja:callHook` and
`wja:emptyResponsePolicy` are new terms). No instance facts invented anywhere.

## Authored (13 files, commit 5fc3e96fd)

| file | notes |
|---|---|
| package.toml | new; named outputs `queries`/`templates` (the FM-GEN-005 resolution surface W641a found missing) |
| ontology.ttl | +145 lines: wja: succession vocabulary (4 classes, ~30 properties) |
| queries/ffi.rq | ported; **extended**: `call_hook` (wja:callHook, default "call") and `empty_response_policy` (wja:emptyResponsePolicy, default "substitute-empty-object") columns per W641c |
| queries/meta.rq, cargo.rq, registry.rq, examples.rq | ported verbatim (project-neutral: select consumer facts), headers re-attributed |
| templates/abi/ffi.rs.tmpl | ported; `<abi_path>::call` → `<abi_path>::{{ call_hook }}`; contract comment parameterized; empty-response block guarded by `empty_response_policy` — unknown values render a `compile_error!` in the generated crate (passthrough-empty is structurally unsound under the boxed/vec free contract: a len-0 response cannot round-trip capacity>=1 reconstruction, so it is refused at compile time, not silently rendered). W641c points (a)(b)(c) were already parameterized in the precursor (abi_path, return_convention, symbol_suffix, input_release_policy); (d) is now a named, guarded variable |
| templates/abi/abi_meta.rs, cargo_config.toml, capability_registry.json, op_examples.json, artifacts.sha256 | ported; only the rendered "Rendered by ggen (...)" attribution comment re-attributed |
| pack.toml | unchanged (no schema-risk edits; outputs live in package.toml, mirroring the precursor) |

## Validation

- `ggen graph validate --files .../rust-wasi-wasmex-pack/ontology.ttl` →
  `{"quads":200,...,"files_checked":1}`, clean.
- During authoring, tooling corruption injected stray tokens into ontology.ttl and
  ffi.rq drafts; both were fixed in place and re-validated (final files parse clean;
  the sync trial + diff is the end-to-end proof — a corrupt SPARQL or Tera file would
  have failed FM-GEN-005 / rendered garbage).

## Falsifier (W641a retry) — executed on real consumer

Trial manifest migration in ~/affidavit (ggen.toml wasi block → rust-wasi-wasmex-pack,
templates → `abi/*.tmpl`, queries unchanged names):

- `ggen sync run` → **exit 0**
- `git diff affidavit-wasm/` → 4 files, 5 lines, **zero structural change**:
  - 3 x `"Rendered by ggen (wasi-json-abi-pack)"` → `"(rust-wasi-wasmex-pack)"`
    attribution comment lines (config.toml, abi_meta.rs, ffi.rs) — honest re-attribution;
  - `op-examples.json` chain_hash `199d1e6a…` → `d6cd5e0c…` — **pre-existing checkout
    staleness, proven by ablation**: reverting the manifest to the old pack and re-running
    sync reproduces the identical op-examples drift (and only it) on the unmodified
    manifest. Independent of this lane.
- `ARTIFACTS.sha256` **unchanged** (mode Create, pin untouched); `capability-registry.json`
  byte-identical; `artifact-pin.json` untouched.
- Post-trial: consumer ggen.toml and rendered tree restored to HEAD (`git status` clean
  except pre-existing untracked `mutants.out*`).

## W641c integration (coordinator course-correction, addressed)

The four ffi conflict points are parameterized as query columns + template variables:
`abi_path` (precursor already had), `call_hook` (new), `empty_response_policy` (new,
single sound value + compile_error guard). Defaults render byte-identical to the
verified in-tree core's shell. A generated ffi.rs can therefore bind an in-tree core
that names its entry differently (wja:callHook) or lives at another module path
(wja:abiModulePath) without template edits. Digest sidecar note acknowledged: no
graphlaw rebuild or sidecar touched by this lane.

## Standing / open edges

- ALIVE: pack surfaces render the affidavit contract byte-identically (modulo disclosed
  comment attribution); ggen sync exit 0 through package.toml outputs resolution.
- NOT DONE HERE (by lane boundary): affidavit's own manifest migration + rendered-tree
  landing (the 3-line attribution + pre-existing op-examples drift are the consumer
  lane's diff to land); cargo build/test of a migrated subject not run (no subject
  exists until the consumer lands).
- BLOCKED(push-carries-foreign-commits): branch is ahead 3 of origin; commits
  08c58b6f6 (aaif-vanilla-pack) and 1258729a1 (lane-lease gitignore) are other lanes'
  unpushed work. Pushing would publish them. Fast-forward push is safe mechanically
  (`git push` would be ff) but publishes foreign work — coordinator decision.
- Pre-existing, not this lane: baseline 18-file trust-plane staleness (W641a #1);
  op-examples golden-receipt drift root cause (affi-wasm.ttl golden fixture vs pinned
  chain_hash) deserves its own lane.
