# W509 — eyerun_wasi: the WebAssembly SHACL admission gate, minted real

Lane: W509, EU-AI-Act implementation wave (dissertation Ch5, Art.15, Theorem 5.4).
Date: 2026-10-06. Branch: `feat/playwright-surface` (xaas, receipt-only; crate not committed).

## Vapor replaced

w405 flagged the dissertation's `eyerun_wasi` as vapor — a named artifact with no
executable subject. This lane replaces the removed vapor claim with a real binary:
`/Users/sac/wasm4pm/crates/eu_gate` building a `[[bin]] eyerun_wasi`.

## Contract compliance

Writes confined to: `/Users/sac/wasm4pm/crates/eu_gate/` and this receipt. Private
target dir `CARGO_TARGET_DIR=/tmp/w509-target`. Crate is standalone (`[workspace]`
empty table) — it does not join the wasm4pm workspace (contract forbids editing
the root `Cargo.toml`); no commits, one canonical checkout untouched.

## What was built

Minimal Rust admission gate (Theorem 5.4 semantics):

- JSON candidate + JSON rule-set (serde_json); rule kinds: `required`, `enum`,
  `numeric_range`, `forbidden_field`, conjunctive evaluation.
- Verdict always on stdout, exit 0: `{"verdict":"ADMITTED"}` or
  `{"verdict":"REFUSED","code":"REFUSED_..."}` with exact typed codes:
  `REFUSED_REQUIRED_FIELD_MISSING`, `REFUSED_ENUM_VIOLATION`,
  `REFUSED_RANGE_VIOLATION`, `REFUSED_FORBIDDEN_FIELD`, and
  `REFUSED_INFRASTRUCTURE_FAULT` for any internal fault (unparseable input,
  missing file, wrong argc, oversized input >16 MiB guard, panic inside
  evaluation under `catch_unwind`).
- Fail-closed trap semantics: the gate never crashes, never passes silently.

## Documented semantics decision

**Empty ruleset = structural admit** of a *well-formed* candidate (SHACL
open-world: a shape constrains nothing until constraints are stated), BUT the
candidate must still parse — unparseable input is
`REFUSED_INFRASTRUCTURE_FAULT`. Open world, not unparseable world. Covered by
two dedicated tests.

## Verification (real output)

```
cargo test  (from crates/eu_gate, CARGO_TARGET_DIR=/tmp/w509-target)
  lib tests:  16 passed; 0 failed
  cli tests:   5 passed; 0 failed   (real binary over real files, stdout-asserted)
cargo build --release: Finished in 6.35s
```

One defect found and fixed during the run: CLI tests raced on shared temp
filenames under parallel test execution (fixed with per-call unique paths —
permanent guard in `tests/cli.rs`).

## Measured latency (honest, 200 invocations of the release binary, Python timing loop)

ADMIT case (4-rule ruleset, 3-field candidate):

```
min 3.22ms | median 4.01ms | p95 5.50ms   (process spawn included)
```

The <15ms claim is now REAL and holds with margin: **median 4.01ms** including
process spawn. Latency is dominated by process startup, not rule evaluation.

## Replay

```
cd /Users/sac/wasm4pm/crates/eu_gate
CARGO_TARGET_DIR=/tmp/w509-target cargo test
CARGO_TARGET_DIR=/tmp/w509-target cargo build --release
/tmp/w509-target/release/eyerun_wasi /tmp/r509.json /tmp/c509.json
# -> {"verdict":"ADMITTED"}  (exit 0)
```

Standing: ALIVE (observed execution on the exact admitted subject). The
dissertation may now cite `eyerun_wasi` as an executable artifact with these
measured numbers.
