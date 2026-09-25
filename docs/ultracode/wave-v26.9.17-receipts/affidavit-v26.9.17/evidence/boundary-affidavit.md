# Boundary Receipt — r7 qualify-boundary(affidavit, cap-standing)

SA2A release v26.9.17 qualification wave, 2026-09-17. Agent 7 of 10.
Boundary: the standing/evidence court — sworn evidence artifacts (`issue-affidavit`),
independent verification records backing ALIVE/refused standings.

## Pinned subject

- Repo: /Users/sac/affidavit (Rust crate `affidavit` v26.6.22, `affi` CLI)
- Pinned HEAD: `7f1caf6488842bc332c118bf3d3eaf8e9c72da8a` on `main` (re-confirmed via `git rev-parse HEAD`)
- Working-tree drift (2 files, NOT mine, left untouched, never stashed):
  - `Cargo.toml`: adds `[patch.crates-io] wasm4pm-compat = { path = "/Users/sac/wasm4pm-compat" }`
  - `Cargo.lock`: 61 lines churn — notably `wasm4pm-compat` 26.6.13 (registry) → 26.8.7 (local path)
  - Drift did NOT break the court: all five sibling PATH crates exist under /Users/sac/;
    `clap-noun-verb` is 26.6.2 in BOTH locks, so the e2e flag failures below are pre-existing
    at HEAD, not drift-caused. All verification below ran under the drift as found.
- Work branch: `fix/affidavit-v26.9.17-boundary` from pinned 7f1caf6. Tip `3106f64`.
  No push, no PR, no merge (per hard constraints).

## Verification court discovered

- `.github/workflows/rust.yml`: `cargo fmt --all -- --check` is the declared REAL blocking
  gate (rustfmt needs no sibling crates); build/test jobs are honest continue-on-error.
- `.github/workflows/web.yml`: web `tsc --noEmit` + `next build` (not exercised — not on
  the standing boundary).
- Test gates: `tests/e2e.rs` (lifecycle + tamper through the real binary),
  `tests/cli_dispatch.rs` (dispatch + §6 transport contract), `tests/adversarial.rs`
  (tamper teeth), `tests/court_law_witness.rs` (refusal-law court), `cargo test --lib`.
- justfile mirrors fmt-check / rust-build / rust-test / golden.

## Capability probe (standing/evidence surface) — file:line citations

- 7-stage certify pipeline: `src/verifier.rs:47-76` — pure, decidable
  (decode → check_format → chain_integrity → continuity → verify_commitments →
  evaluate_profile → verdict). BLAKE3 rolling-hash chain recompute in `src/chain.rs`.
- Tamper evidence: `tests/adversarial.rs` — tamper_commitment/reorder/inject all REJECT
  at chain_integrity, with teeth (untampered control ACCEPTs); deserialization forgery
  gate (ADR-3) rejects before the pipeline ("chain hash mismatch", stderr, non-zero exit).
- Exit-code contract: REJECT = 2 via `exit_codes::REJECT` (`src/handlers.rs:381-385`,
  B6 comment); deserialization gate exits 1 (anyhow ExecutionError).
- Refusal-law court: `tests/court_law_witness.rs:1-575` — 45 witnesses that the
  wasm4pm-compat court refuses each named violation (OcelRefusal, DfgRefusal,
  ProcessTreeRefusal, EventLogRefusal, BpmnRefusal, PetriRefusal, PowlRefusal,
  DeclareRefusal, ReceiptRefusal, InteropRefusal) — no ghost variants; anti-hollow
  design stated at lines 1-17.
- Issuance verbs (pack-generated, interface-authoritative): `src/verbs/emit.rs:13`,
  `assemble.rs`, `sign.rs`, `attest.rs`, `notarize.rs`, `verify.rs`.
- RECORDED UNSUPPORTED ELEMENT: `UNSUPPORTED(issue-affidavit, cryptographic-signature)`.
  `handlers::sign` (`src/handlers.rs:686-718`) emits JSON claiming
  `"algorithm": "ed25519", "status": "signed"` but performs NO cryptography
  (`"note": "Production: sign chain_hash bytes with key at key_path."`).
  `handlers::notarize` (`:629` region) likewise fakes RFC-3161 ("submit chain_hash to
  a TSA"); `handlers::attest` builds a structural SLSA envelope, unsigned. Evidence
  integrity currently rests entirely on BLAKE3 chain tamper-evidence, not key signatures.

## Commands + exits (observed this session)

At pinned HEAD (before repair):
- `cargo fmt --all -- --check` → **1** (gate RED at HEAD; nightly rustfmt 1.9.0-nightly,
  the repo-pinned toolchain)
- `cargo build` → 0 (Finished dev profile, 1m02s, with drift present)
- `cargo test --lib` → 0 (290 passed)
- `cargo test --test adversarial` → 0 (6 passed); `--test court_law_witness` → 0 (45 passed)
- `cargo test --test e2e` → **101** (5/5 FAILED), `--test cli_dispatch` → **FAILED** (6/6)
- `cargo clippy --lib` → **101** — 223 `clippy::print_stdout` convictions under the lib's
  own `#![deny(clippy::print_stdout)]` (`src/lib.rs:76`)
- Live falsifier v1 (old binary): emit `--type` → CLI refused (`--r#type` only);
  verify positional → refused (`--receipt` required)

At branch tip `3106f64` (after repair):
- `cargo fmt --all -- --check` → 0
- `cargo test --lib` → 0 (290 passed)
- `--test adversarial` → 0 (6), `--test court_law_witness` → 0 (45),
  `--test cli_dispatch` → 0 (6), `--test e2e` → 0 (5) — 352 tests, 0 failures
- Live falsifier v2 (repaired binary, /tmp/affi-court2):
  - `affi receipt emit --r#type init --object app:service --payload p.txt` → 0
  - `affi receipt assemble --out r.json` → 0
  - `affi receipt verify --receipt r.json` → **0**, `verdict: ACCEPT [core/v1] — all
    stages passed` on stderr, stdout clean
  - tampered (event_type "init"→"forged", single field): `verify` → **1**, stderr
    `chain hash mismatch: receipt claims 6586aa8f…, recomputed 8acda990…`, stdout clean

## Classification + repairs (FOND)

Pinned HEAD state = **build-broken** (declared fmt gate red; both behavioral witness
suites of the standing court red). Repairs on `fix/affidavit-v26.9.17-boundary`,
atomic local commits, each narrow:

1. `72cd90f` — fmt gate: `cargo fmt --all`, 7 src + 4 test files, purely mechanical
   (repo-pinned nightly rustfmt). No semantic change.
2. `ada0b29` — `src/handlers.rs`: route `verify`/`show` substantive output (human + JSON)
   from `println!` to `eprintln!`. This restores the ARDPRD §6 transport contract that
   BOTH red suites encode ("output on stderr per §6", "verify<->show inversion") and the
   lib's own `deny(clippy::print_stdout)`. Evidence the handlers were the drift, not the
   tests: two independent suites agree on the contract; lib root denies print_stdout;
   commit d9f6fca shows a prior eprintln→println consumer drift in the same file.
3. `3106f64` — `tests/e2e.rs` + `tests/cli_dispatch.rs`: align invocations with the
   pack-generated CLI surface (`--type` → `--r#type` [13 sites], positional → `--receipt`
   [7 sites]). Verb wrappers are auto-generated and "authoritative for the CLI interface"
   (their header comment), so the consumer witnesses were stale, not the pack.

Alternates considered and refused: changing the verb wrappers or the clap-noun-verb
dependency (pack/upstream-owned, out of this repo's lawful edit surface);
rewriting test stream expectations to stdout (would encode the drift as law and violate
the lib's own deny attribute). Remaining pre-existing debt, NOT repaired (out of scope,
not a gate): 222 further print_stdout convictions across the lib under clippy;
`examples/golden_run.sh` still uses `--type`/positional (stale docs artifact);
`ARDPRD.md` referenced by docs/ but absent from repo root.

## Falsifiers attempted

- Single-field tamper through the REAL binary → caught (exit 1, chain hash mismatch). Survived.
- Chain-consistent objectless receipt → refused by OCEL court by name
  (`EmptyEventObjectLinks`) — witnessed in e2e (5/5 green), the court is load-bearing on
  the production verify path, not just in unit tests. Survived.
- Drift-blame falsifier: "e2e failures are caused by the working-tree drift" → FALSIFIED:
  clap-noun-verb is 26.6.2 in both locks; failures are pre-existing at HEAD.
- "Signatures back the sworn evidence" → FALSIFIED: sign/attest/notarize are structural
  stubs; no cryptography executes. Typed as UNSUPPORTED element above.

## Standing

Verification/tamper-evidence court: ALIVE (observed execution this session, exact
subject, falsifier survived). Signing/notarization sub-surface: structural stub, no
crypto — UNSUPPORTED(issue-affidavit, cryptographic-signature); owner pack must supply
Ed25519/Sigstore signing over chain_hash + real RFC-3161 TSA before "sworn" is
cryptographically true.

**Boundary yield: qualified** (verification court real and witnessed, repairs landed
narrowly; unsupported element ledgered). **Overall standing: PARTIAL_ALIVE.**

## What the operator did NOT have to write

All 3 commits (fmt sweep, §6 transport restore, witness-flag alignment), their
diagnosis (gate inventory, stream-contract archaeology, drift blame), all 352 test
executions, both live falsifier runs, and this receipt. The operator wrote nothing.
