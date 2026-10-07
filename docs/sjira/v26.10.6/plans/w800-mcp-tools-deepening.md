# W800 — MCP Tools Deepening (tool-surface court for `/mcp`)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf6` (canonical checkout, no worktree)
- **Lane**: W800, `MIX_BUILD_ROOT=_build-laneW800`, `MIX_ENV=test`, asdf shims PATH
- **Standing**: **ALIVE** (6/6 tests passed on the exact subject; mock gate `[]`)

## Scope

Backlog: the production MCP server (`/mcp` scope in `lib/xaas_web/router.ex` ->
`XaasWeb.McpScope.mount/0` -> `AshAi.Mcp.Router`, 3 Library read tools,
per-request audited by `XaasWeb.Plugs.AuditMcpToolCall`) had W728 audit-log
courts but no tool-surface court. This lane adds it.

## μ / diff (handwritten; test-only lane)

- NEW `test/xaas_web/mcp_tools_deepening_test.exs` — 6 Chicago-style courts via
  real ConnCase JSON-RPC 2.0 POSTs to `/mcp` (initialize/session flow,
  protocol "2024-11-05"), no mocks:
  - (a) `tools/list` returns exactly `{list_books, books_by_grade_band, active_curations_for_grade}` (Set equality)
  - (b) `tools/call :list_books` returns the real seeded `Book` row (id/title/author asserted)
  - (c) `:books_by_grade_band` band filter (min 4 / max 6) includes the grade-5 row, excludes grade-1 and grade-8 rows
  - (d) unknown tool → real typed JSON-RPC error `-32602`, `"Tool not found: no_such_tool_xyz"` (AshAi.Mcp.Server, server.ex:803-813)
  - (e) audit cross-check of W728 at router level: `AuditLogEntry` count with `action == "mcp.tool_call.invoked"` is exactly +1 after initialize, +3 after 2 tool calls (one row per HTTP request, matching the plug moduledoc contract)
  - (f) determinism: two identical `tools/call` payloads decode identically, no error key

## Commands / exits (real tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW800 \
  mix test test/xaas_web/mcp_tools_deepening_test.exs
......
Finished in 1.5 seconds (0.00s async, 1.5s sync)

Result: 6 passed

$ mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test/xaas_web/mcp_tools_deepening_test.exs"]))'
[]
```

## Verification ladder

narrow (this file, 6/6 green) — broader `mix test` not run on this lane
(concurrent-session dev-compile restriction; coordinator owns integration run).

## Falsifiers

- A 4th tool appears on `/mcp` without a graph change → court (a) fails.
- `by_grade_band` filter drifts (off-by-one / non-inclusive bounds) → court (c) fails.
- `AuditMcpToolCall` stops writing per-request rows, or double-writes → court (e) fails.
- Unknown-tool handling changes error code/message → court (d) fails.

## Typed gaps / notes

- First compile pass surfaced real test-code errors (missing `require Ash.Query`
  for the `Ash.Query.filter/2` macro; unused `conn` in `call_tool/5`) — fixed in
  this lane, rerun green. No product code touched.
- Court (e) counts by `action == "mcp.tool_call.invoked"` only; it does not
  duplicate W728's plug-level field assertions (actor hashing, metadata shape).
- `_build-laneW800` deletion was denied by the permission system in this
  session — left on disk for the coordinator to remove at integration
  (lane-lease law: it is a lease, not an asset).

## Replay

```
cd /Users/sac/xaas && git rev-parse HEAD   # a0723bf6
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web/mcp_tools_deepening_test.exs
```
