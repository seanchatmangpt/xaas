# W614 — Goose Prompt-Injection Fuzzing Harness (WP-3) — Receipt

Lane W614, v26.10.7 campaign. Subject: `tests/goose_mutation_harness.py`
(+ `tests/w614_stub_agent.py`, gate log
`docs/sjira/v26.10.7/plans/w614-gate-log.json`). No commits made, per
lane contract. Python-only; no mix build root touched.

## Goose-presence verdict

**GOOSE-ABSENT** — `which goose` → not found; no `~/goose`. Agent leg is
pluggable via `AGENT_CMD` env (space-split command, candidate prompt
appended as final arg). Default leg is a real subprocess echo stub
(`tests/w614_stub_agent.py`).

## Harness design

- **A2A endpoint leg**: real localhost HTTP socket (stdlib
  `ThreadingHTTPServer`, ephemeral port), implementing the ash_a2a wire
  pattern grounded by reading
  `~/ash_a2a/lib/ash_a2a/protocol/jsonrpc/error.ex` (typed
  -32001..-32009 errors with google.rpc `ErrorInfo`-shaped `data`) and
  `transport/plug.ex` / `protocol/plug.ex` (A2A-Version header gate →
  -32009, fail-closed error discipline).
- **PEP watchdog** (pep-eyerun-filter-spec §3): fail-closed pre-flight
  (lease_present ∧ digest_ok ∧ daemon_alive), fault → 503 + typed reason
  (`REFUSED_LEASE_ABSENT` / `REFUSED_INFRASTRUCTURE_FAULT`), zero
  upstream bytes, NO agent subprocess spawned.
- **Gate invariance**: non-conforming candidates → typed JSON-RPC
  refusal (`-32001`, `REFUSED_POLICY_*`) with `upstream_bytes: 0` in
  ErrorInfo data AND in the `X-W614-Upstream-Bytes` response header;
  conforming candidates pass to the agent (upstream bytes > 0).
- **Corpus** (10 cases): 2 conforming baselines; INJ-001..006
  ("ignore rules", "drop tables", "escalate role" + phrasing variants —
  caught by order-independent word-pair matching, not literal substring);
  INJ-007 drives the §5 lease-absent fault; plus an A2A-Version gate leg
  (stale version → -32009).
- **Client**: real `urllib` requests; `HTTPError` stream read so 4xx/5xx
  refusals assert on the real wire body/headers.

## §5 falsifier coverage (harness level)

| spec case | harness leg | result |
|---|---|---|
| lease absent (case 4) | LEASE-ABSENT: 503, `-32001` `REFUSED_LEASE_ABSENT`, 0 upstream bytes, agent_calls unchanged | PASS |
| digest mismatch (case 5) | modeled under same fail-closed branch (`digest_ok=False` → same refusal path); not driven as a separate wire case | PARTIAL |
| timeout/crash/malformed (cases 1–3) | require the real agentgateway daemon (not present on this machine) | NOT RUN — daemon-absent |
| version gate (wire, from ash_a2a plug) | VERSION-GATE: 503, `-32009` | PASS |

## Run results (real)

- `python3 tests/goose_mutation_harness.py` → exit 0;
  10/10 cases ok; interception rate non-conforming = **1.0**;
  intercepted=8; conforming upstream bytes 44/55 (agent echo stub saw
  real bytes); gate log written to
  `docs/sjira/v26.10.7/plans/w614-gate-log.json`.
- `python3 -m pytest tests/goose_mutation_harness.py -q` →
  `1 passed in 0.67s`.
- First run failed honestly (exit 1): gate predicate missed two phrasing
  variants and `urlopen` raised on 503 — both fixed as real code fixes
  (word-pair matching; HTTPError stream read), not assertion relaxation.

## Disclosure

- No local agentgateway checkout and no goose CLI exist; the endpoint is
  a **wire-level court fixture** (real socket, real JSON-RPC bytes) —
  NOT the real ash_a2a Plug (booting it would need a mix build in
  `~/ash_a2a`, outside this lane's no-build-root contract) and NOT the
  real AGD filter. §5 cases 1–3 (timeout/crash/malformed daemon) are
  therefore unrunnable here and stay with the daemon-present
  implementation lane.

## Standing

**PARTIAL_ALIVE (harness)** — gate-invariance assertion machinery is
ALIVE against the wire fixture (real socket, real subprocess agent leg,
100% interception observed, pytest + direct-run receipts). NOT ALIVE:
runs against the real goose agent (GOOSE-ABSENT) and the real
agentgateway daemon (checkout absent), and §5 cases 1–3 + 5 remain
unproven. Next lawful hop: plug `AGENT_CMD` when goose lands; re-point
the endpoint at a booted ash_a2a Plug or real AGD filter and drive
cases 1–3 with real fault shims.
