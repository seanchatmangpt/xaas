# W984kj — realtime socket layer probe (unclaimed family)

Subject: /Users/sac/xaas @ feat/playwright-surface, 2026-10-08. Lane W984kj.
Scope: `lib/xaas_web/channels/` (absent), `user_socket.ex` (absent),
`lib/xaas_web/endpoint.ex` socket mounts. No commit made (per lane contract).

## Census / dispositions

| Surface | Status | Disposition |
|---|---|---|
| `lib/xaas_web/channels/` | directory does not exist | THIN (no Phoenix channels in the app) |
| `user_socket.ex` | absent repo-wide | THIN |
| `use Phoenix.Channel` modules | zero under `lib/` (`Xaas.Semantics.AuthorityChannel` is a semantic registry module, not a Channel; separately courted by `test/xaas/semantics/authority_channel_test.exs`, `authority_channel_incident_witness_test.exs`, `refusal_atom_census_test.exs`) | COVERED (different family) |
| `endpoint.ex` `socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])` | stock socket, no custom `connect/3`, no topic guards, no join-time logic | INDIRECT-COVERED via LiveViewTest mounts (e.g. `test/xaas_web/next_read_live_deepening_test.exs`); newly DIRECT-probed by this lane (below) |
| `endpoint.ex` `socket("/phoenix/live_reload/socket", ...)` | dev-only (`code_reloading?` block), never mounted in test/prod | THIN (out of test surface by construction) |

## New court

`test/xaas_web/channels/socket_court_w984kj_test.exs` — 3 tests, real
endpoint dispatches, zero mocks:

1. non-upgraded `GET /live` falls through the socket mount to the router and
   answers 404 (measured: Phoenix endpoint-level socket mounts are matched
   only on websocket upgrade; plain HTTP falls through). Pins the
   socket-vs-router boundary.
2. unrouted control path answers 404 (same fall-through shape).
3. real `Phoenix.LiveViewTest.live/2` mount of `/witness` through the `/live`
   socket over sandboxed real Postgres — the load-bearing probe: fails if
   the socket mount or its session `connect_info` is dropped.

Measured correction during the lane: the initially hypothesized
"non-upgraded GET on the socket path returns 400" is FALSE in this stack
(phoenix 1.7.24) — the actual observed status is 404 fall-through. The court
pins the measured behavior, not the hypothesis.

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984kj
  mix test test/xaas_web/channels/socket_court_w984kj_test.exs` →
  `Result: 3 passed`, exit 0.
- Mock gate `scan_mock_usage(["test","lib"])` → `[]`, exit 0.

## Standing

PARTIAL_ALIVE → socket layer typed THIN + /live mount DIRECT-COVERED.
Falsifier: deleting `socket("/live", ...)` from endpoint.ex fails court
probe 3. Build-root lease `_build-laneW984kj` removed at integration.
