# W728 — AuditLogEntry deepening (`/mcp` audit trail)

- Repo: `/Users/sac/xaas` (canonical checkout, branch `feat/playwright-surface`, HEAD `a0723bf6`)
- Lane build root: `_build-laneW728` (left for coordinator)
- Subject: `Xaas.Operations.AuditLogEntry` was undocketed; this lane adds the missing
  deepening tests only. No `lib/` changes, no commit (per lane contract).

## New file

`test/xaas/operations/audit_log_deepening_test.exs` — 4 tests, Chicago-style
(real `Plug.Router` surface, real plug pipeline, real sandboxed `Xaas.Repo` rows,
`Ash.count!`/`Ash.read!` state assertions, zero mocks; mock gate on the file: `[]`):

- **(a) one request, one row, real fields** — GET `/mcp/list_books?grade_band=middle`
  dispatched through `W728.TestRouter` → `W728.MountedMcpApp` (real `AuditMcpToolCall`
  plugged only inside the `/mcp` scope, mirroring `XaasWeb.Router`'s real pipeline
  shape) writes exactly one row: `action="mcp.tool_call.invoked"`,
  `resource_type="McpRequest"`, `resource_id="/mcp/list_books"`,
  `actor_id="token:" <> sha256(token) hex[0..16]`, full metadata map, `%DateTime{}`.
- **(b) scope pin** — non-`/mcp` path (`/api/books`) through the same router returns 404
  and writes **zero** rows (row count unchanged).
- **(c) malformed request still audited — real behavior asserted, not assumed** — the plug
  runs pre-dispatch and unconditionally, so an unknown tool path POSTed with a malformed
  JSON body still gets a 400 **and** exactly one audit row (`POST`, real path recorded).
- **(d) immutability per the resource's real actions** — the resource defines only
  `:read` + `:create`; `Ash.update/2` raises
  `RuntimeError "Required primary update action"`, `Ash.destroy/1` returns
  `{:error, %Ash.Error.Invalid{errors: [...NoPrimaryAction...]}}` (lazy resolution —
  typed error, not a raise; asserted as observed), and the row re-reads byte-identical in
  `action`/`resource_id`/`actor_id`/`metadata`.

## Command + real output (final run)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW728 \
  mix test test/xaas/operations/audit_log_deepening_test.exs
# EXIT=0
#     Result: 4 passed   (0.8s sync; excludes :stress/:eu_ai_act/... standard tags)
```

Mock gate (scan_mock_usage on the new file only): `[]`.

## Standing

- **ALIVE (lane-local)**: all four behaviors (a)-(d) hold on the exact subject
  `a0723bf6 + this test file`, driven through a real plug pipeline and real Postgres
  rows. `eu_ai_act` tag deliberately NOT applied: the `/mcp` audit rows are the closed
  ERRC observability item, not an Art 12 record-keeping surface (in-file justification
  in the moduledoc).

## Notes / typed gaps

- Plug-level tests already existed (`test/xaas_web/plugs/audit_mcp_tool_call_test.exs`,
  drives `AuditMcpToolCall.call/2` by hand). This lane adds the pipeline-shaped surface
  (real `Plug.Router` dispatch) plus scope pin + immutability the old file lacks.
- `Phoenix.ConnTest.dispatch/2` does not exist (dispatch is /5 against `@endpoint`), so
  the mounted surface is dispatched via `Plug.Router.call/2` directly — still a real
  pipeline, no mocks.
- No `lib/` defects found in `AuditLogEntry` or `AuditMcpToolCall` on this pass; the
  resource's deny-by-default policy floor (only `:read` bypassed) held under all probes.
- Pre-existing environment noise (not session-introduced, not asserted): PromEx/Grafana
  upload warnings, AshA2A legacy-compat warnings.
