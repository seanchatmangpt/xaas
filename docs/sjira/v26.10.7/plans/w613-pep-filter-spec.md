# W613 Receipt — agentgateway-pep-eyerun Filter Specification (WP-3)

- **Subject**: `/Users/sac/xaas/docs/sjira/v26.10.7/agentgateway/pep-eyerun-filter-spec.md`
- **Standing**: PARTIAL_ALIVE (spec) — fully specified, executable surface deferred
- **Mode**: SPEC-ONLY. `ls ~ | grep -i gateway` returned empty — no local agentgateway
  checkout exists, so no Rust skeleton was written and no `cargo check` was run.
  Disclosed in the spec (§ header note + §6 exclusions), not buried.

## Grounding evidence (real, read this session)

1. **eyerun_wasi wire contract** — read from source:
   `/Users/sac/wasm4pm/crates/eu_gate/src/lib.rs` (RefusalCode stringification lines
   39–43; `MAX_INPUT_BYTES = 16 MiB`; `evaluate_checked` double `catch_unwind` with
   fail-closed `REFUSED_INFRASTRUCTURE_FAULT`) and `src/main.rs` (exit-code discipline:
   always 0, verdict in stdout, serialization guarded).
2. **Binary verified present**: `/tmp/w653b-target/release/eyerun_wasi` and
   `/tmp/w509-target/release/eyerun_wasi` (real `ls` output this session).
3. **Behavior court exists**: `~/xaas/test/eu_ai_act/eyerun_wire_deepening_test.exs`
   (W706) — real-subprocess pin of stdout JSON, typed refusals, exit discipline,
   3× determinism. Read in full this session.
4. **WASM host exemplar**: `/Users/sac/ash_a2a/priv/graphlaw/` (composition-catalog
   primitive J) — `praxis_graphlaw.wasm`, `MANIFEST.json`, `WASMEX_HOST_MANIFEST.json`,
   `conformance_vectors.json` verified present via `ls`.
5. `cargo` present at `/Users/sac/.cargo/bin/cargo` — the skeleton leg is runnable
   once the repo materializes.

## What the spec covers (all five WP-3 sections)

1. Transport: UDS SOCK_STREAM NDJSON to a `serve`-mode eyerun_wasi daemon; exact
   request/verdict schema reusing eyerun's existing vocabulary verbatim; optional
   phase-2 shm fast path for >256 KiB payloads.
2. Watchdog: 15 ms hard deadline (12+2+1 decomposition), tokio timeout, fail-closed
   on timeout/crash/malformed — drop + `REFUSED_INFRASTRUCTURE_FAULT` log + 503 /
   JSON-RPC `-32000` / A2A `-32009`-class mapping; connection pool with capped
   backoff, circuit-open still fails closed.
3. Authority: mandatory lease file `{lease_id, ruleset_digest, not_after}`;
   absent/expired/digest-mismatch → `REFUSED_LEASE_ABSENT`, fail-closed; fail-open
   structurally inexpressible (no config knob).
4. Config schema + registration: AGD `policies.pepEyerun` block, six fields typed
   with defaults; §4.1 discloses the AGD surface is provisional until bound against
   a real checkout.
5. Falsifier (for W614): five fault-injection cases (timeout shim, SIGKILL,
   malformed response, lease absent, digest mismatch), each asserting all three
   legs — zero upstream bytes, typed log code, protocol error.

## Commands / exits

- `ls ~ | grep -i gateway` → empty (exit 1 from grep; repo absent)
- `grep -ril eyerun|wasi` sweeps over `~/xaas/lib`, `priv`, full tree → located
  W706 court + W653b receipt references
- `which cargo` → `/Users/sac/.cargo/bin/cargo`
- Binary `ls` → both release binaries present
- Spec file written and Edit-repaired (3 malformed table/heading fragments fixed
  in-place); not committed, per lane contract.

## Exclusions / next hops

- Native AGD `Filter` trait registration deferred to the repo-present lane.
- No commit made (lane contract). Next hop: materialize agentgateway checkout →
  write `pep_eyerun.rs` skeleton against the real filter trait → `cargo check`
  → W614 runs the five-case falsifier.
