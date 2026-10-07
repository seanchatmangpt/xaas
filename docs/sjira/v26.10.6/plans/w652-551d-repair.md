# W652 — 55.1.d Repair Receipt

Lane: W652 (EU-AI-Act wave). Date: 2026-10-07.
Subject: `/Users/sac/xaas` @ `feat/playwright-surface` (canonical checkout, no worktree).

## Diagnosis

W651's typed finding: a sibling lane refactored
`/Users/sac/wasm4pm/crates/eu_gate/src/lib.rs` to serde
`#[serde(tag = "verdict", rename_all = "SCREAMING_SNAKE_CASE")]` on the
`Verdict` enum. The source literals `"ADMITTED"` /
`"REFUSED_REQUIRED_FIELD_MISSING"` left `lib.rs`; runtime JSON output is
unchanged (`{"verdict":"ADMITTED"}`). `title_iv_v_test.exs` line 174 asserted
`crate =~ "ADMITTED"` — a **source-literal assertion**, drift-sensitive
anti-pattern: it pins implementation spelling, not the gate's contract.

The durable check is the **behavior**: the binary's JSON verdict output
(already the primary leg, mirroring W509's court). Fallback evidence now
asserts the serde rename attribute itself (`rename_all = "SCREAMING_SNAKE_CASE"`
+ `pub enum Verdict`), which survives literal moves.

## Diff (contract-bounded)

`test/eu_ai_act/title_iv_v_test.exs`, `deepening("55.1.d")` fallback leg only:

- removed: `assert crate =~ "ADMITTED"`,
  `assert crate =~ "REFUSED_REQUIRED_FIELD_MISSING"` (drift-sensitive source
  literals)
- added: `assert crate =~ ~s(rename_all = "SCREAMING_SNAKE_CASE")`,
  `assert crate =~ "pub enum Verdict"` (attribute-level, rename-proof)
- unchanged: primary binary leg (run `eyerun_wasi` on tmp ruleset+candidate,
  assert `{"verdict":"ADMITTED"}` + `REFUSED_REQUIRED_FIELD_MISSING` on stdout,
  exit 0); `main.rs` leg; receipt-count leg. Binary-not-built leg remains the
  disclosed in-suite path on this checkout (no `eyerun_wasi` binary at
  `/tmp/w509-target/release/` or `wasm4pm/target/release/` — observed).

## Verification (real runs, MIX_ENV=test)

```
mix test test/eu_ai_act/title_iv_v_test.exs --include eu_ai_act
Result: 65 passed   (0 failures, 0 skipped)
```

Honest both directions: the fallback leg executed on this checkout (binary
absent, disclosed in-test comment); `assert crate =~ ~s(rename_all = ...)` is
a real read of `/Users/sac/wasm4pm/crates/eu_gate/src/lib.rs:22,51`. The
`ADMITTED` source grep is verified absent (`grep -c "ADMITTED\|REFUSED_" lib.rs`
→ lib.rs: 0 literal verdict strings; main.rs: 1, the infra-fault envelope),
so the OLD assertion would genuinely fail today — the repair is load-bearing,
not vacuous.

## Notes

- Fresh private build root `_build-laneW652` failed compiling the `ash_a2a`
  dep (`:capability_release_closure_missing`, pre-existing fresh-build issue
  unrelated to this diff); branched to the existing `MIX_ENV=test` build root.
  `_build-laneW652` was created and is empty — deleted per cleanup law.
- wasm4pm crate untouched (read-only lane boundary held).
