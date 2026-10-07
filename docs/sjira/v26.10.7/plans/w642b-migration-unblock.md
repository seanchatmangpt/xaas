# W642b — migration unblock (pack push + affidavit + ferroplan migrations)

**Standing: ALIVE** — all three falsifiers executed and passed on real subjects; three
commits landed and pushed (fast-forward only, no force).

## Step 1 — ggen-marketplace push unblock

W642 held push at `BLOCKED(push-carries-foreign-commits)` naming 08c58b6f6 +
1258729a1 as foreign unpushed work. Re-verified on disk first: **1258729a1 is already
on origin** (it is origin's tip), so the actual unpushed set ahead of
`origin/feat/aaif-gcp-roadmap-v26.10.5` was 3 commits, each `git show --stat`-verified
as a real completed lane deliverable before push:

| commit | lane | deliverable |
|---|---|---|
| `e987f3717` | rust-wasi pack consolidation | unified rust-wasi-wasmex-pack (pack.toml, ontology, shapes, guest/host/test templates) |
| `08c58b6f6` | aaif-vanilla-pack | Fortune-5 enterprise topology + Chicago test court (13 files, +524) — matches operator's bicameral briefing ("landed") |
| `5fc3e96fd` | W642 (this family) | abi/ render surfaces + queries — the pack completion itself |

Push: `1258729a1..5fc3e96fd` fast-forward, no force. Branch now in sync with origin.

## Step 2 — affidavit migration (W641a retry falsifier)

Subject: `~/affidavit` @ `1056fc6`, branch `feat/advanced-witness-capability-set`.

- Manifest migration: `ggen.toml` wasi block — pack swap + `templates → abi/*.tmpl`
  (queries unchanged names). Only remaining `wasi-json-abi-pack` mention is a comment.
- `ggen sync run` → **exit 0** (ggen 26.9.28).
- `git diff affidavit-wasm/` → **exactly the expected 5 lines**: 3× attribution
  comment (`wasi-json-abi-pack` → `rust-wasi-wasmex-pack`) in config.toml, abi_meta.rs,
  ffi.rs; plus the op-examples.json chain_hash drift `199d1e6a…` → `d6cd5e0c…`
  (pre-existing checkout staleness, proven pack-rendered by ablation in
  w642-pack-completion.md; committed as rendered output with that disclosure).
- `ARTIFACTS.sha256` unchanged (mode Create pin untouched); `capability-registry.json`
  and `artifact-pin.json` byte-identical (git diff --quiet verified).
- `cargo build --target wasm32-wasip1 --profile wasm` → **exit 0**.
- Commit `9da04a4` (7 files: ggen.toml, .ggen-v2 receipts, the 4 rendered files).
  Pre-existing 18-file trust-plane sync drift (src/crypto_trust_*, benches, tests)
  deliberately **not** committed — its own lane. Pushed: `3b2e413..9da04a4`.

## Step 3 — ferroplan migration (W641b falsifier)

Subject: `~/ferroplan` @ `7808b7a`, branch `main`.

- ggen.toml migrated per W642's pack: pack stanza swap; capability-registry → new-pack
  `queries/registry.rq` (verified byte-identical port: `diff` old vs new query =
  header comment only); op-examples → `examples.rq` + `abi/op_examples.json.tmpl`;
  artifacts pin → `registry.rq` + `abi/artifacts.sha256.tmpl` (no artifacts.rq
  successor; same mapping as the affidavit precedent).
- **Course-correction during execution**: the pack's `abi/capability_registry.json.tmpl`
  hardcodes the `<prefix>_free` export model and omits `memory`; ferroplan's live ABI
  genuinely exports `fp_dealloc` + `memory` (lib.rs `src/wasi_abi.rs:194-236`), and the
  local template `ontology/templates/wasm_capability_registry.json.tmpl` is a documented
  LOCAL DIVERGENCE (crates/ferroplan-wasm/PACK-GAPS.md). A full pack-template swap
  rendered `fp_alloc/fp_call/fp_free` — a factually false exports list — and was
  rejected. Local template retained for that one rule.
- `ggen sync run` → **exit 0**; `capability-registry.json`, `op-examples.json`,
  `ARTIFACTS.sha256` **byte-identical after re-render** (empty diff on `registry/`).
- Commit `6a68f3f` (5 files: ggen.toml + 4 receipt files). Pre-existing dirty state
  untouched (`crates/ferroplan/src/lib.rs` + untracked `reachability.rs`, `wasm` —
  another lane's in-flight work, mtimes 2026-10-06; confirmed via mtime + absent from
  sync-rendered surfaces). Pushed: `7808b7a..6a68f3f` on main, fast-forward.

## Per-repo SHA table

| repo | branch | before (local / origin) | commit | after (local=origin) | push |
|---|---|---|---|---|---|
| ggen-marketplace | feat/aaif-gcp-roadmap-v26.10.5 | `5fc3e96fd` / `1258729a1` | — (publish-only) | `5fc3e96fd` | ff `1258729a1..5fc3e96fd` |
| affidavit | feat/advanced-witness-capability-set | ahead-21 head `9da04a4` / `3b2e413` | `9da04a4` | `9da04a4` | ff `3b2e413..9da04a4` |
| ferroplan | main | `7808b7a` / `7808b7a` | `6a68f3f` | `6a68f3f` | ff `7808b7a..6a68f3f` |

## Open edges (not this lane)

- affidavit trust-plane 18-file sync drift (src/crypto_trust_* + op-examples golden
  fixture root cause) still open — deserves its own lane.
- Pack template `abi/capability_registry.json.toml` hardcodes the free-symbol export
  model; consumers with a dealloc+memory ABI (ferroplan) must keep a local template.
  Pack-side parameterization (e.g. `export_model` query column like W642's
  `call_hook`/`empty_response_policy` parameterization) is a candidate pack lane.
- ferroplan: another lane's in-flight lib.rs/reachability.rs work on disk, untouched.

## Falsifier tails (real commands)

- ggen-marketplace: `git push` → `1258729a1..5fc3e96fd` (ff, exit 0)
- affidavit: `ggen sync run` exit 0; `cargo build --target wasm32-wasip1 --profile wasm` exit 0; pins quiet-diff verified
- ferroplan: `ggen sync run` exit 0; registry/ diff empty after re-render
