# W270 — A2A v1 SSE gap closed (v26.10.6)

Subject: /Users/sac/xaas @ feat/playwright-surface (uncommitted lane work, no git actions taken).
Dep: /Users/sac/ash_a2a pinned 86214551 (v26.10.4). Verified against the pinned tree's
`AshA2A.Protocol.Plug`, `AshA2A.Transport.Plug`, `AshA2A.Protocol.Agent`,
`AshA2A.Protocol.JSONRPC`, `AshA2A.Protocol.Client` (SSE decoder), `MIME` registry.

## What the dep provides (read + empirically verified, not guessed)

The pinned dep serves `message/stream` server-side; no protocol fork needed:

- `AshA2A.Protocol.Plug` dispatches `message/stream` itself, gated on
  `agent_card_opts: [capabilities: %{streaming: true}]` (`streaming_declared?/1`,
  plug.ex:312). With the gate open it calls `AshA2A.Protocol.Plug.SSE.stream_message/5`.
  But for a REPLY-BACKED agent (`{:reply, parts}`) that path answers
  `-32603 internal_error` with `data: {:not_streaming, task}` — the dep's own pinned
  behavior (dep test TQ-05, test/ash_a2a_a2a_methods_test.exs:114).
- Forcing the agent to return `{:stream, parts}` makes SSE work but empirically regresses
  `message/send` to a stuck `TASK_STATE_WORKING` (no pump on the send path; verified in
  ExUnit) — rejected.
- `AshA2A.Transport.Plug` ("message/stream for every skill", TQ-05): drop-in mount that
  streams EVERY reply — task snapshot frame, one ArtifactUpdate per artifact, terminal
  StatusUpdate with the task's REAL state — while keeping `message/send` synchronous
  `TASK_STATE_COMPLETED` (both proven in ExUnit over the real agent GenServer).
- A `{:stream, enum}` reply is the only streaming shape on the `Protocol.Agent` behaviour;
  there is NO `handle_message_stream/2` callback, and `message/send` vs `message/stream`
  are indistinguishable inside `handle_message/2` (same `GenServer.call`).

## What xaas changed (W270 in-fence edits)

1. `config/config.exs` — registered `config :mime, :types, %{"text/event-stream" => ["sse"]}`.
   Verified: `MIME.extensions("text/event-stream") == ["sse"]` under MIX_ENV=test.
   (The plug sets its own content-type, so this is hygiene, not load-bearing.)
2. `lib/xaas_web/a2a/next_read_ash_agent.ex` — NO final change (a streaming bridge was
   tried and reverted after it empirically regressed message/send; file matches pre-lane state).
3. `e2e/a2a-v1.spec.cjs` — aligned to real wire forms:
   - role `"user"` -> `"ROLE_USER"` (bare "user" is invalid_role on the v1.0 wire).
   - message/send state `"completed"` -> `"TASK_STATE_COMPLETED"` (W217 ground truth),
     with a tasks/get terminal-poll loop (W313's version retained).
   - SSE court restored from the stale W313 refusal form (-32004) to the closed-seam
     wire truth: `text/event-stream`, `data:` frames, `TASK_STATE_COMPLETED`,
     reply content (`grade:3`) present.
   - malformed-JSON court sends a Buffer (Playwright JSON-quotes a bare string, which
     made the server see valid JSON and answer -32600; direct node probe proves the
     real wire answer for a genuinely malformed body is -32700).
4. NEW ExUnit court `test/xaas_web/a2a/v1_sse_test.exs` — 3 cases:
   - router-path message/stream case-branch pinning either the closed-seam SSE form
     (text/event-stream + TASK_STATE_COMPLETED) or the pre-seam refusal (-32603
     not_streaming) — real router dispatch.
   - plug-level court: `AshA2A.Transport.Plug` + real agent streams the full SSE
     sequence AND `message/send` stays synchronous `TASK_STATE_COMPLETED` (the
     composition that closes the gap without regressing send).

## Coordinator seam (landed during the lane, by W305, not by W270)

router.ex `/a2a/v1` mount now uses `XaasWeb.A2A.V1TransportPlug` (wraps
`AshA2A.Transport.Plug`, restores the card's `Cache-Control: public, max-age=300` the
transport hardcodes to max-age=60). This is exactly the composition W270's ExUnit
plug-level court proves. Fence respected: W270 did not edit router.ex.

## Gate outputs (real, this session)

- ExUnit: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web/a2a/v1_sse_test.exs test/xaas_web/a2a/v1_protocol_test.exs`
  -> `8 passed` (0 failures).
- Playwright: `INTERNAL_API_TOKEN=dev-e2e-token npx playwright test e2e/a2a-v1.spec.cjs`
  on a fresh :4000 -> `7 passed (21.2s)`.

## Pre-existing failure (not session-introduced, outside fence)

Mid-lane, `v1_protocol_test.exs` "agent card" failed on `Cache-Control == public,
max-age=300` (dep serves max-age=60) — resolved by the coordinator's V1TransportPlug
wrapper landing during the lane; final ExUnit run is 8/8.

## Standing

ALIVE — observed execution on the real surface: ExUnit 8/8, Playwright 7/7, SSE frames
with terminal TASK_STATE_COMPLETED over HTTP on :4000.

## W310c post-W305 trio

2026-10-06, lane W310c, fresh :4000 boot via committed chain
(`node ./e2e/global-setup.cjs --catalog && PHX_SERVER=true INTERNAL_API_TOKEN=dev-e2e-token mix run --no-halt`,
log /tmp/w310c-server.log, port cleared of prior beams first).

Command: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test
e2e/a2a-v1.spec.cjs e2e/witness.spec.cjs e2e/ggen-workbench.spec.cjs`

Result (real output, exit=0): `16 passed (17.3s)`
- a2a-v1.spec.cjs: 7/7 (incl. message/send happy path and message/stream SSE with
  terminal TASK_STATE_COMPLETED) — W297b falsifier satisfied: no 406, V1TransportPlug
  SSE surface observed over HTTP on the fresh tree.
- witness.spec.cjs: 3/3 (seeded via global-setup W55_SEED_OK).
- ggen-workbench.spec.cjs: 6/6 (typed 422 REFUSED fences all firing).

Standing: ALIVE — observed execution on the exact post-W305 tree. Server killed after run.
