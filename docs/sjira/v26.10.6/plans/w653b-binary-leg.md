# W653b — eyerun_wasi release build + 55.1.d binary leg (receipt)

Lane: W653b, EU-AI-Act wave v26.10.6. Repo: /Users/sac/wasm4pm (canonical, unmodified).
Contract writes: this file + /tmp/w653b-* fixtures only.

## Build (task 1)

`cd /Users/sac/wasm4pm/crates/eu_gate && CARGO_TARGET_DIR=/tmp/w653b-target cargo build --release`
(note: `eu_gate` is NOT a workspace member of wasm4pm's root Cargo.toml — workspace-root
`-p eu_gate` fails with "did not match any packages"; built from the crate dir instead.)

```
Compiling serde_derive v1.0.229
Compiling eu_gate v0.1.0 (/Users/sac/wasm4pm/crates/eu_gate)
Finished `release` profile [optimized] target(s) in 6.21s
```

Binary: **/tmp/w653b-target/release/eyerun_wasi** (628,928 bytes, 2026-10-07 00:07)

## Binary leg — real runs (task 2)

Fixtures: /tmp/w653b-fixtures/{rules,cand_ok,cand_missing,malformed}.json
Ruleset: `{"rules":[{"type":"required","field":"artifact_id"}]}`

| case | candidate | stdout | exit |
|---|---|---|---|
| satisfying | `{"artifact_id":"W653B-001",...}` | `{"verdict":"ADMITTED"}` | 0 |
| violating | `{"note":"...required field absent"}` | `{"verdict":"REFUSED","code":"REFUSED_REQUIRED_FIELD_MISSING"}` | 0 |
| malformed | `{"broken` | `{"verdict":"REFUSED","code":"REFUSED_INFRASTRUCTURE_FAULT"}` | 0 |

## Test with binary present (task 3)

title_iv_v_test.exs expects the binary at `/tmp/w509-target/release/eyerun_wasi`
(line 148). Placed symlink: `/tmp/w509-target/release/eyerun_wasi -> /tmp/w653b-target/release/eyerun_wasi`
(test only reads/executes it; symlink left in place for W652/integration — remove not needed,
/tmp-scoped and outside both repos).

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW653b \
  mix test test/eu_ai_act/title_iv_v_test.exs --include eu_ai_act
→ Result: 65 passed   [exited with code 0]
```

The binary leg executed (File.exists? guard at line 150 was true via the symlink).

## Handoff to W652 / integration

Binary location: **/tmp/w653b-target/release/eyerun_wasi** — republish or symlink to
whatever path integration standardizes on (test currently reads /tmp/w509-target/release/eyerun_wasi).
