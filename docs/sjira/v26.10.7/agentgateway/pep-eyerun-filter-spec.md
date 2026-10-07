# agentgateway-pep-eyerun Filter Specification

- **Lane**: W613 (WP-3), v26.10.7 release campaign
- **Status**: SPEC-ONLY — no local agentgateway checkout exists (`ls ~ | grep -i gateway` returned nothing on this machine), so no Rust skeleton file was written and no `cargo check` was run. Disclosure per task contract.
- **Exemplar grounding**:
  - `eyerun_wasi` wire contract — read from real source `/Users/sac/wasm4pm/crates/eu_gate/src/lib.rs` and `src/main.rs`, release binary verified present at `/tmp/w653b-target/release/eyerun_wasi` and `/tmp/w509-target/release/eyerun_wasi`; behavior pinned by the real-subprocess court `~/xaas/test/eu_ai_act/eyerun_wire_deepening_test.exs` (W706).
  - WASM admission-kernel exemplar — `ash_a2a:priv/graphlaw/` (composition-catalog primitive J): `praxis_graphlaw.wasm` driven through wasmex with `MANIFEST.json`, `WASMEX_HOST_MANIFEST.json`, `conformance_vectors.json`; one executable law, many runtimes.
- **Falsifier owner**: W614 (Goose lane) proves the watchdog fires.

## 1. Transport — local domain socket / shared memory with eyerun_wasi

### 1.1 Socket contract

The filter (in agentgateway's Rust proxy process) speaks to a long-lived
`eyerun_wasi` admission daemon over a **local Unix domain socket**, not a
per-request subprocess spawn — the W706 court's subprocess form is the
batch/CLI shape; the daemon form reuses the identical JSON wire schema over
SOCK_STREAM:

```
SOCK_STREAM, AF_UNIX, path: /var/run/eyerun/pep.sock (config: socket_path)
framing: one JSON document per direction, newline-delimited (NDJSON)
peer: eyerun-daemon (long-lived eyerun_wasi process in serve mode)
```

The daemon is the existing `eyerun_wasi` binary extended with a `serve`
mode (same `evaluate_checked` core, same verdict schema). No new admission
semantics are introduced by this spec — the filter is pure transport +
watchdog.

### 1.5 Message schema

Request (filter → daemon), one NDJSON line:

```json
{
  "id": "req-<uuid>",
  "op": "admit",
  "ruleset": { "rules": [ {"type": "required", "field": "id"} ] },
  "candidate": { "id": "W706-001" }
}
```

Response (daemon → filter):

```json
{ "id": "req-<uuid>", "verdict": "ADMITTED" }
```
```json
{ "id": "req-<uuid>", "verdict": "REFUSED", "code": "REFUSED_REQUIRED_FIELD_MISSING" }
```

Verdict vocabulary is exactly eyerun_wasi's: `ADMITTED` or
`REFUSED` + `code` in {`REFUSED_REQUIRED_FIELD_MISSING`,
`REFUSED_ENUM_VIOLATION`, `REFUSED_RANGE_VIOLATION`,
`REFUSED_FORBIDDEN_FIELD`, `REFUSED_INFRASTRUCTURE_FAULT`} (read from
`lib.rs` lines 39–43). The filter never interprets rule semantics; it
forwards the candidate payload and relays the typed verdict.

For streaming protocols the filter consults the PEP once per
request-head; the verdict binds to the whole request body (buffered until
verdict, per §2 fail-closed discipline).

### 1.6 Shared-memory fast path (optional, phase 2)

For payloads > 256 KiB, the request line carries
`"shm": {"path": "/dev/shm/eyerun-<id>", "len": N}` and the daemon reads
the candidate from the mapped region, returning the same verdict schema.
Same watchdog budget applies; `REFUSED_INFRASTRUCTURE_FAULT` on any shm
open/mmap failure. Phase 2 — the socket-only path must pass the falsifier
first.

## 2. Watchdog — sub-15ms budget, fail-closed

### 2.1 Budget decomposition

| Stage | Budget |
|---|---|
| Filter→daemon write + daemon read/parse/evaluate | 12 ms |
| Daemon→filter verdict write | 2 ms |
| Filter decision + response-mapping | 1 ms |
| **Total hard deadline** | **15 ms** |

The filter arms a tokio `time::timeout(15ms)` around the full round trip
(per request, per verdict awaited). On timeout, crash (daemon process
exit), or malformed/partial NDJSON response, the filter applies
**fail-closed**:

1. Payload is dropped (never forwarded upstream).
2. Structured log: `REFUSED_INFRASTRUCTURE_FAULT` with fields
   `{request_id, cause: timeout|crash|malformed_response, elapsed_ms, socket_path}`.
3. Client-visible error mapped by protocol:

| Inbound protocol | Error emitted |
|---|---|
| HTTP | `503 Service Unavailable` (no body semantics beyond a generic payload) |
| JSON-RPC (MCP, A2A) | code `-32000` (server error), message `pep: infrastructure fault` |
| A2A v1 (JSON-RPC) | `-32009`-class server error, per ash_a2a transport precedent |

Mapping is one-way: infrastructure faults never masquerade as admission
verdicts and verdicts never masquerade as transport errors.

### 2.2 Daemon health

The filter holds one pooled connection; on fault the pool marks the peer
dead and re-dials with capped backoff (1ms→2ms→4ms, max 3 attempts, then
circuit-open for 1s). While circuit-open, every request is answered
`REFUSED_INFRASTRUCTURE_FAULT` + protocol error from §2.1 — fail-closed
throughout. A supervising daemon restart (launchd/systemd contract, out of
spec scope) recovers service; the filter never starts the daemon itself.

## 3. Authority — lease required, fail-closed

The filter refuses to pass any payload unless it holds a valid
**PEP lease** bound to the active ruleset. Lease state is read from
config (`lease_path`, §4) — a receipt-style file carrying
`{lease_id, ruleset_digest, not_after}`.

- **Lease absent, expired, or ruleset_digest mismatch → fail-closed**:
  same drop/log/error mapping as §2.1 with log code
  `REFUSED_LEASE_ABSENT` (distinguishing code, same fail-closed behavior).
  `REFUSED_LEASE_ABSENT` is a filter-local code, never emitted by the
  daemon.
- The lease requirement is not configurable — no `allow_lease_absent`
  knob exists in the schema. Fail-open is structurally inexpressible.
- Lease renewal is out of scope (issuer-side); the filter only verifies
  `not_after` against wall clock and digest against the loaded ruleset.

## 4. Config schema + registration

agentgateway (AGD) filters are configured in the AGD `Config` under
`policies` → per-listener filter chains; this filter registers as
`type: pep-eyerun`:

```yaml
policies:
  pepEyerun:
    socketPath: /var/run/eyerun/pep.sock
    rulesetPath: /etc/eyerun/ruleset.json
    leasePath: /etc/eyerun/lease.json
    timeoutMs: 15
    maxPayloadBytes: 16777216   # 16 MiB, mirrors MAX_INPUT_BYTES in eu_gate lib.rs
    shmThresholdBytes: 262144   # phase 2; omit in phase 1
```

| Field | Type | Default | Notes |
|---|---|---|---|
| `socketPath` | string | required | UDS path to eyerun daemon |
| `rulesetPath` | string | required | ruleset JSON handed to daemon per request |
| `leasePath` | string | required | lease receipt file (§3) |
| `timeoutMs` | int | 15 | hard cap 50; values >50 REFUSED at config-admission |
| `maxPayloadBytes` | int | 16777216 | mirrors eyerun's `MAX_INPUT_BYTES` |
| `shmThresholdBytes` | int | 262144 | 0 disables shm path (phase-1 default) |

Registration (phase 1): agentgateway's built-in wasm/CustomHTTP filter
surface carries the PEP as an external process + filter config; native
`Filter` trait registration is phase 2 and lands with the real checkout
(skeleton file deferred to lane W616 or equivalent — see §6 exclusions).

## 4.1 AGD config surface is provisional

Because no local agentgateway checkout exists, the §4 YAML/registration
surface is written against agentgateway's public documentation shape
(AGD policies/filter-chains), **not** against a locally read
`crates/` filter trait. When the repo lands locally, the skeleton must
bind against the real trait signatures and this section re-derived — a
re-derivation gate, not a rewrite.

## 5. Falsifier — how W614 proves the watchdog fires

The Goose harness (W614) proves fail-closed by producing each fault
condition and asserting the drop + typed refusal, Chicago-style (real
socket, real daemon process, real dropped payload — no mocks):

1. **Timeout**: daemon wrapped in a `sleep 10` shim on the socket →
   filter must drop payload, log `REFUSED_INFRASTRUCTURE_FAULT`
   (cause=timeout), return 503. The upstream must observe zero bytes.
   Sub-15ms asserted by measuring the filter's response latency.
2. **Crash**: `SIGKILL` the daemon mid-flight → same assertions.
3. **Malformed response**: shim emits non-JSON bytes → same assertions.
4. **Lease absent**: remove `leasePath` between requests → request
   dropped, log `REFUSED_LEASE_ABSENT`, 503; no daemon round trip occurs
   (lease check is pre-flight).
5. **Lease digest mismatch**: mutate ruleset under an unchanged lease →
   `REFUSED_LEASE_ABSENT` (digest mismatch variant).

Each case asserts all three legs: payload dropped upstream, typed log
code, protocol error. A watchdog that returns any upstream byte on any of
the five cases fails the falsifier.

## 6. Exclusions (除 — non-adopted premises)

- A local agentgateway checkout was assumed possible and is not present
  on this machine (`ls ~ | grep -i gateway` → empty). Consequence: no
  Rust skeleton, no `cargo check`, and the §4 AGD surface is provisional
  pending re-derivation against the real trait. This lane is SPEC-ONLY
  and its standing reflects that.
- Per-request subprocess spawn is rejected (latency budget incompatible);
  the daemon form is adopted. The W706 subprocess court remains the
  batch-mode contract.
- Fail-open under watchdog fault is rejected structurally (§2, §3).
- Native AGD `Filter` trait registration is deferred to the repo-present
  implementation lane; phase 1 binds through the external-process +
  config surface.

## 7. Standing

**PARTIAL_ALIVE (spec)** — transport, watchdog, authority, config, and
falsifier are fully specified and grounded in the real eyerun_wasi wire
contract (source read, binary verified, court exists) and the graphlaw
wasm host exemplar. NOT ALIVE: no executable filter exists; §4's AGD
registration surface is provisional until bound against a real checkout.
Next lawful hop: materialize the agentgateway checkout, then the
skeleton + `cargo check` leg per task contract.
