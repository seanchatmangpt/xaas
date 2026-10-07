# W61 — castle_kernel gate: pinned CASTLE_BIN materialization + gate run

Wave-2 lane W61, v26.10.6. Closes W36's blocker (CASTLE_BIN at pinned SHA).

## Standing

**PARTIAL_ALIVE** — binary materialized and gate executed for real; 2/3 tests pass;
1 deterministic failure from a pre-existing source defect (atom vs string protocol
literal), identical under CI parity. Not BLOCKED: the W36 blocker (no pinned-SHA
binary) is fully closed.

## Exact subject

- xaas checkout: /Users/sac/xaas, branch `feat/playwright-surface`, subject at run
  time d1db2b03 (working tree; no git mutations performed).
- castle source: pinned SHA `a71801dcc0c0783eb8a4544cbee8b40bb0b30296` — present in
  local /Users/sac/castle object store (verified `git rev-parse <sha>^{commit}`).
- Materialization: `git archive <sha> | tar -x -C /tmp/castle-pin-w61` — outside all
  canonical checkouts; /Users/sac/castle untouched.

## Env recipe (CI parity with castle-paas-bridge.yml)

CI builds with `cargo +1.85.0 build --locked --bin castle`. 1.85.0 is not installed
locally and the pinned Cargo.lock requires rustc >= 1.86 (icu_properties_data 2.3.0
needs 1.88), so 1.85.0 **cannot build the pinned lockfile** — CI's 1.85.0 step would
fail on this exact Cargo.lock. Local build used the next available pinned-class
toolchain:

```bash
mkdir -p /tmp/castle-pin-w61
(cd /Users/sac/castle && git archive a71801dcc0c0783eb8a4544cbee8b40bb0b30296 \
   | tar -x -C /tmp/castle-pin-w61)
cargo +1.91.1 build --locked --bin castle --manifest-path /tmp/castle-pin-w61/Cargo.toml
# -> Finished `dev` profile in 35.53s, 1 dead_code warning
# binary: /tmp/castle-pin-w61/target/debug/castle
# sha256: 4c305bd3b18dd8108c2b19a5e75439425443798ad5e5eb9db23bd1edc1be829b
# sanity: $CASTLE_BIN release info --format json
#   {"kind":"CASTLE_FORTUNE5_GLOBAL_V1","name":"CASTLE","release":"26.8.18+dfcm.1",...}
```

Gate:

```bash
mkdir -p /tmp/castle-evidence-w61
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH \
CASTLE_BIN=/tmp/castle-pin-w61/target/debug/castle \
CASTLE_BIN_SHA256=4c305bd3b18dd8108c2b19a5e75439425443798ad5e5eb9db23bd1edc1be829b \
CASTLE_EVIDENCE_ROOT=/tmp/castle-evidence-w61 \
MIX_ENV=test mix test --include castle_kernel test/xaas/castle_bridge_test.exs
# EXIT=2, 2/3 passed, 1 failed
```

## Results

- PASS: `direct private action is refused without a real XaaS Reactor receipt`
- PASS: `caller-supplied provider command policy is refused before CASTLE actuation`
- FAIL: `real XaaS actuation nests exact CASTLE BRCE receipts and replays without a
  second DO` — `{:error, :REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH}` raised in
  `Xaas.Operations.RouteCastleRun.execute`.

## Failure diagnosis (pre-existing source defect, not a build artifact)

`lib/xaas/castle.ex`:

- line 108: `@protocol "CASTLE_PAAS_XAAS_BRIDGE_V1"` (string — base)
- line 114 (generated override block `GGEN:XAAS_CASTLE_CONTRACT:BEGIN`):
  `@protocol :"CASTLE_PAAS_XAAS_BRIDGE_V2"` (**atom**)
- line 590: `manufacture/2` builds the checkpoint with `"protocol" => contract.protocol`
  (the atom). `Xaas.Actuation.checkpoint_external/2` persists it in the outer receipt
  (JSON round trip) — the atom encodes to the string `"CASTLE_PAAS_XAAS_BRIDGE_V2"`.
- `RouteCastleRun.execute` reloads the persisted checkpoint and
  `verify_runtime_checkpoint` (castle.ex:872) compares the reloaded
  **string** against the **atom** `:"CASTLE_PAAS_V2"` literal → always unequal →
  deterministic refusal.

The base-case string literal (V1) works; the generated V2 override emitted an atom
where the checkpoint comparison demands a string. Same defect reproduces in CI. Fix
belongs to the ggen castle-contract template (emit a string literal), which is
outside this lane's file ownership (lane owns only this receipt + /tmp scratch). The
test itself confirms it is not env-related: both non-env-dependent refusals (no
Reactor context, ambient policy) pass, and the failure is a pure data comparison,
not kernel drift (`kernel_binary_sha256` check would have emitted
`REFUSED_CASTLE_KERNEL_DRIFT` instead).

## Toolchain note for CI parity

The pinned Cargo.lock (castle @ a71801dcc) requires rustc >= 1.86 (transitively
1.88 via icu 2.3.0). CI's `rustup toolchain install 1.85.0` +
`cargo +1.85.0 build --locked` step in `.github/workflows/castle-paas-bridge.yml`
will fail with the same `requires rustc 1.88` resolver error. CI workflow needs
1.91.x (or a lockfile/toolchain bump) — file with lane coordinator; this lane owns
no workflow edits.

## Cleanup / ownership

- Wrote: this receipt only.
- Scratch: /tmp/castle-pin-w61, /tmp/castle-evidence-w61, /tmp/w61-test.log (all
  outside canonical checkouts; deletable).
- No source edits, no git mutations anywhere.
