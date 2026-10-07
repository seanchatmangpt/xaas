# W74 lane receipt — beam4pm rust4pm WASM artifact close

- Subject: `/Users/sac/beam4pm` main @ `813eb924` (dirty tree pre-existing, untouched; no source edits, no git mutations)
- Closes W52's gate residual: 3 test failures + 13 invalid groups, all root-caused to the missing native artifact `native/rust4pm-wasm/target/wasm32-wasip1/release/rust4pm_wasm.wasm`.

## Build (step 1-2)

- Script: `scripts/rust4pm_wasm_build.sh` (read in full; guards for cargo/rustup + wasm32-wasip1 target, then `cargo build --release --target wasm32-wasip1`).
- Command: `bash scripts/rust4pm_wasm_build.sh` — exit 0.
- rustup was present; `rustup target add wasm32-wasip1` was a no-op (target std already installed).
- Build tail (verbatim):
  ```
  Compiling process_mining v0.6.2 (rust4pm.git?rev=89a6a30#89a6a301)
  Compiling rust4pm-wasm v0.1.0 (/Users/sac/beam4pm/native/rust4pm-wasm)
  Finished `release` profile [optimized] target(s) in 27.16s
  -rwxr-xr-x@ 1 sac  staff  1293971 Oct  6 12:26 native/rust4pm-wasm/target/wasm32-wasip1/release/rust4pm_wasm.wasm
  6a66c0f155e07a0792ef72b473e532970aaa8a26bc846d036f63b424f375b0f2  native/rust4pm-wasm/target/wasm32-wasip1/release/rust4pm_wasm.wasm
  ```
- Artifact: 1,293,971 bytes, sha256 `6a66c0f155e07a0792ef72b473e532970aaa8a26bc846d036f63b424f375b0f2`.

## Test rerun (step 3)

- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/beam4pm_ocel_session_facts_test.exs test/beam4pm_authorship_gate_test.exs` then the 5 previously-invalid files (`beam4pm_deviation_admission_test.exs`, `beam4pm_eds_test.exs`, `beam4pm_powl_conformance_e2e_test.exs`, `beam4pm_powl_conformance_test.exs`, `beam4pm_powl_edges_test.exs`).
- Environment repair (not a source edit): rebar deps in `beam4pm/deps/` had lost owner-execute bits (`drw-------` on `yamerl/src`, `aws_signature`, others); `chmod -R u+rwX /Users/sac/beam4pm/deps` restored them so rebar3 could read `src/*.app.src`. No file contents changed.

### Results

- OcelSessionFacts + AuthorshipGate: **45/47 passed**. W52 failure 1 (OcelSessionFacts missing-wasm error shape) is fixed.
- The 2 remaining failures are a DIFFERENT, pre-existing cause — not the missing wasm:
  - `BeamPM.AuthorshipGateTest` x2 (`test/beam4pm_authorship_gate_test.exs:341` and `:359`): `REFUSED_SHA_DRIFT` on `test/beam4pm_evidence_chain_test.exs` — the file is modified in beam4pm's pre-existing dirty tree (`git status`: ` M`), so its on-disk sha256 (`443f2e7a...`) no longer matches the manifest-admitted digest (`35c95fe2...`). Out of W74 scope (would require either a source/manifest edit or a git mutation).
  - Gate output (abbreviated): `REFUSED_SHA_DRIFT: test/beam4pm_evidence_chain_test.exs (admitted sha256 35c95fe2..., on disk 443f2e7a... -- an edit to admitted hand-authored source is new debt: re-admit it with the new digest in ontology.ttl)`
- Previously-invalid groups (5 files): **34 passed, 5 skipped, 0 failures, 0 invalid** — all 13 setup-invalidation groups from W52 cleared by the artifact build.

## Verdict

- W52's missing-wasm cause: **CLOSED (ALIVE)** — artifact built (sha256 `6a66c0f1...`), W52 failure 1 fixed, all 13 invalid groups pass.
- Remaining test debt is 2 AuthorshipGate failures from a pre-existing dirty-tree edit to `test/beam4pm_evidence_chain_test.exs` (sha drift vs the hand-authored manifest) — a separate cause, outside W74 scope (no source edits / git mutations allowed).
- Standing: rust4pm WASM-engine tests ALIVE; AuthorshipGate sha-drift remains UNKNOWN/BLOCKED[pre-existing-dirty-tree], owned by the tree owner, not W74.
