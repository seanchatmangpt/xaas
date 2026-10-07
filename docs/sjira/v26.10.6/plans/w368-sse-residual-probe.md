# W368 — SSE residual probe: does `message/stream` push incremental SSE over the wire?

Lane W368, repo /Users/sac/xaas @ feat/playwright-surface, read-only diagnosis lane.
Date 2026-10-06. Contract path only; no lib/test edits.

## Source analysis

- `/Users/sac/xaas/lib/xaas_web/a2a/v1_transport_plug.ex` — pure seam wrapper: registers
  `restore_card_caching` before_send and delegates to `AshA2A.Transport.Plug`; it does not
  touch the SSE path.
- `/Users/sac/xaas/deps/ash_a2a/lib/ash_a2a/transport/plug.ex` — `stream_message/4` (lines
  ~411-451) uses real chunked SSE: `start_sse` does `put_resp_header("content-type",
  "text/event-stream")` + `send_chunked(200)` (line ~514-519); `send_event/3` emits each frame
  with `chunk(conn, data)` (line ~522-529). Incremental, not buffered single-response.
- App-side agent `/Users/sac/xaas/lib/xaas_web/a2a/next_read_ash_agent.ex` (lines 86-100):
  `handle_message/2` delegates to `NextReadUserAgent.handle_message` and returns
  `{:reply, parts}` / `{:input_required, parts}` — a **complete reply**, not a
  `Task` with `metadata.stream`. The plug therefore takes the `{:ok, %Message{}}` or
  `{:ok, %Task{}}` branches: SSE-shaped wire, but all frames emitted in one burst after the
  agent has finished computing.
- Router mount `lib/xaas_web/router.ex:216-220` (agent: NextReadAshAgent).

## Live probe (server booted `mix phx.server`, PORT=4068, token w368-token; killed after)

Agent card `GET /a2a/v1/.well-known/ep...` declares `capabilities.streaming: true`.

Probe 1 (`"browse"` → input_required):
```
1791330871.212  data: {... "result":{"task":{...,"status":{"state":"TASK_STATE_INPUT_REQUIRED"...}}}}
1791330871.216  (blank)
1791330871.221  data: {... "result":{"statusUpdate":{...,"state":"TASK_STATE_INPUT_REQUIRED"}}}
```
2 frames, Δ 8ms.

Probe 2 (`"as:guest browse grade:3"` → completed reply):
```
frame 1  t=...881.900  result.task (carries the full artifact text already)
frame 2  t=...881.904  result.artifactUpdate
frame 3  t=...881.909  final result.statusUpdate TASK_STATE_COMPLETED
```
3 frames, Δ ~4ms inter-arrival — a burst.

Response headers: `200`, `content-type: text/event-stream`, `transfer-encoding: chunked`,
`cache-control: no-cache` (card caching override correctly not applied).

## Verdict

**SPEC-ALIGNED-BUT-BUFFERED-ACCEPTABLE.**

The transport is genuinely chunked SSE (send_chunked/chunk per frame — source + headers +
multi-frame wire). But the app-side agent is reply-backed, so every frame for a request is
emitted in a single burst once the reply is complete; no incremental content streaming
occurs. The wire shape is conformant with the ash_a2a conformance statement row 13/15
(deps/ash_a2a/docs/reference/a2a-v1-conformance.md rows "Chunked streaming" /
"A non-streaming reply is one artifact"; a reply-backed agent legitimately produces a
terminal-burst shape), and the agent card's `streaming: true` refers to the transport
capability, which is real. w302's residual "real streaming remains open lib-side" is
therefore resolved as: the lib-side transport already streams; the remaining gap, if anyone
wants true incremental push, is app-side only — have `NextReadAshAgent.handle_message/2`
return a Task with `metadata.stream` enum (e.g. wrap the single reply as a 1-chunk stream or
tokenize the reply). No lib edit needed for spec conformance; the residual is app-side,
optional, and bounded to `next_read_ash_agent.ex`.