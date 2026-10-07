# W625 Receipt — pep-eyerun PEP skeleton (Rust, compiling)

- **Lane**: W625, v26.10.7 release campaign
- **Subject**: `/Users/sac/xaas/docs/sjira/v26.10.7/agentgateway/skeleton/` — standalone std-only Rust crate (`Cargo.toml`, `src/lib.rs`, `src/main.rs`), written but NOT committed (per task contract; git tree left untouched).
- **Standing**: PARTIAL_ALIVE (compiling + smoke-run skeleton; daemon hop is a disclosed placeholder).

## Grounding (O*)

- W613 spec: `docs/sjira/v26.10.7/agentgateway/pep-eyerun-filter-spec.md` (read in full this session).
- Verdict vocabulary + output contract read from real source
  `/Users/sac/wasm4pm/crates/eu_gate/src/lib.rs` lines 39–43 (`RefusalCode`:
  `REFUSED_REQUIRED_FIELD_MISSING`, `REFUSED_ENUM_VIOLATION`,
  `REFUSED_RANGE_VIOLATION`, `REFUSED_FORBIDDEN_FIELD`,
  `REFUSED_INFRASTRUCTURE_FAULT`) and the `Verdict` serde-tag shape
  `{"verdict":"ADMITTED"}` / `{"verdict":"REFUSED","code":"..."}`.
- `REFUSED_LEASE_ABSENT` is filter-local per spec §3 (never daemon-emitted);
  implemented as a distinct code in the skeleton's `RefusalCode` enum.
- cargo available at `~/.cargo/bin` (W613 finding, re-confirmed by use).

## What the skeleton implements

- UDS server (`std::os::unix::net::UnixListener`, SOCK_STREAM, NDJSON) —
  spec §1.1 transport.
- Watchdog: `set_read_timeout(15ms)` per read; fault path emits
  `REFUSED_INFRASTRUCTURE_FAULT` verdict line + HTTP-503-shaped error record
  (`HTTP/1.1 503` + `X-Pep-Refusal` header), structured fail-closed log line
  with `{cause: timeout|crash|malformed_response, elapsed_ms, socket_path,
  code}`. **Witnessed firing**: real read timeout observed at elapsed_ms=16
  on an idle connection during smoke run (see tails below).
- Lease pre-flight (spec §3, BEFORE daemon round trip): requires
  `lease_id` / `ruleset_digest` / `not_after`; absent field, expired
  `not_after`, digest mismatch, or missing lease file →
  `REFUSED_LEASE_ABSENT`. Not configurable — fail-open structurally
  inexpressible (no such knob in the code).
- Pass-through verdict on conforming payloads — **placeholder** (phase-0,
  see Disclosures).
- Zero dependencies (Cargo.toml `[dependencies]` empty) — offline
  check-able by design.

## Disclosures (skeleton-grade, not production)

1. **Daemon hop not wired**: conforming payloads return a placeholder
   `ADMITTED` from `pass_through_placeholder` — no eyerun daemon exists on
   this machine (W613 confirmed), so the real socket hop to a
   daemon-mode `eyerun_wasi` is the daemon-present lane's first edit.
   Fail-closed paths are real; the admit path is not a real admission.
2. **Watchdog is per-read, not per-round-trip**: single-threaded std +
   read timeouts, disclosed as skeleton-grade; spec §2.1 budgets the full
   round trip (tokio `time::timeout`) in the real lane.
3. **JSON handling is a minimal flat-field extractor**, not a parser —
   sufficient for the lease triple + `op`/`id` extraction; serde lands
   with the real lane.
4. **Idle-connection timeout**: an open connection that goes quiet after a
   verdict also takes the fault path (observed in smoke run); the real
   lane distinguishes idle-keepalive from in-flight watchdog expiry.
5. **AGD filter-trait surface untouched**: spec §4.1 re-derivation gate
   still open — this skeleton is the standalone transport/lease/watchdog
   core only, not an agentgateway `Filter` implementation.

## Commands + exits (real tails)

```
$ CARGO_TARGET_DIR=/tmp/w625-target cargo check
    Checking pep_eyerun_skeleton v0.1.0
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.06s   → exit 0

$ CARGO_TARGET_DIR=/tmp/w625-target cargo build
   Compiling pep_eyerun_skeleton v0.1.0
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.33s   → exit 0

$ CARGO_TARGET_DIR=/tmp/w625-target cargo test
running 6 tests
test tests::http_mapping_is_503 ... ok
test tests::verdict_lines_match_eyerun_shape ... ok
test tests::lease_missing_field_refused ... ok
test tests::lease_expired_refused ... ok
test tests::conforming_lease_admits ... ok
test tests::lease_digest_mismatch_refused ... ok
test result: ok. 6 passed; 0 failed                        → exit 0

$ /tmp/w625-target/debug/pep_eyerun_skeleton /tmp/pep.sock <lease> unpinned-skeleton
CONFORMING: '{"verdict":"ADMITTED"}\n'            (placeholder admit, valid lease)
MALFORMED:   '{"verdict":"REFUSED","code":"REFUSED_INFRASTRUCTURE_FAULT"}\n' + HTTP/1.1 503 record
LEASE_ABSENT (file removed): '{"verdict":"REFUSED","code":"REFUSED_LEASE_ABSENT"}\n'
server log: {"event":"pep_fail_closed",...,"cause":"timeout","elapsed_ms":16,...}
```

## Target-dir hygiene

`CARGO_TARGET_DIR=/tmp/w625-target` used throughout — no `target/` under
the skeleton dir; the repo tree stays light. Build artifacts remain at
`/tmp/w625-target` (replayable: `cargo check && cargo build && cargo test`
from the skeleton dir with any target dir).

## Replay

```
cd /Users/sac/xaas/docs/sjira/v26.10.7/agentgateway/skeleton
PATH=$HOME/.cargo/bin:$PATH CARGO_TARGET_DIR=/tmp/w625-target cargo check && cargo build && cargo test
/tmp/w625-target/debug/pep_eyerun_skeleton /tmp/pep.sock /tmp/lease.json unpinned-skeleton
```

## Falsifiers handed to the daemon-present lane

- W614's watchdog falsifier (spec §5) applies unchanged: timeout / crash /
  malformed / lease-absent / digest-mismatch must each drop + typed-log +
  503. Cases 3–4 (malformed, lease-absent) are already witnessed on this
  subject; cases 1–2 (sub-15ms timeout, SIGKILL crash) still need the
  daemon-present lane because the daemon hop is the placeholder.
- Lease digest-match requires the loaded ruleset digest — currently
  pinned via CLI arg (`unpinned-skeleton` default); real lane reads it
  from `rulesetPath` (spec §4).

---

## SUPERSEDED (2026-10-07, lane W638b)

This skeleton's out-of-process UDS daemon approach is **superseded-by** the
in-process Wasmex host (`Xaas.Semantics.GraphlawWasm`, lane W638; receipts
`w638-*`), per the operator's Wasmex unification directive grounded in
`~/ggen-marketplace` packs `wasi-json-abi-pack` + `beam-wasmex-host-pack`
(in-process packed-u64 ABI via Wasmex).

Skeleton disposition: **KEEP as history** — the Rust skeleton lives under
`docs/sjira/v26.10.7/agentgateway/skeleton/` (docs-only, never shipped lib
code, never a dependency of anything), so it is retained, not deleted.
Falsifier cases 1-5 (W613 spec §5) are carried forward to the Wasmex court.
