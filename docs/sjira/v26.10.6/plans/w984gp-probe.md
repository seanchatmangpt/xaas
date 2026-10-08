# W984gp — MCP-surface unclaimed-family probe receipt

Lane: W984gp · Branch `feat/playwright-surface` (no branch switch, no commit, no stash).
Subject: MCP modules behind the `/mcp` router scope.

## Census (CamelCase grep of each module against test/)

| module | file | disposition |
|---|---|---|
| `XaasWeb.McpScope` | `lib/xaas_web/mcp_scope.ex` | INDIRECTLY-COVERED: real `/mcp` HTTP traffic in `test/xaas_web/mcp_library_tools_test.exs` + `test/xaas_web/mcp_tools_deepening_test.exs` drives the generated `mount/0` forward; gap = the descriptor↔router tool-set contract, now pinned in court section C |
| `XaasWeb.McpDescriptor` | `lib/xaas_web/mcp_descriptor.ex` | UNCOVERED (state-bearing: fail-closed `requires_authority?/1` + full descriptor map): zero references in test/ before this lane |
| `XaasWeb.Plugs.AuditMcpToolCall` | `test/xaas_web/plugs/audit_mcp_tool_call_test.exs`, `test/xaas/operations/audit_log_deepening_test.exs` | COVERED at plug level + one-count at router level; unexercised residue = metadata fidelity (method/path/query_string) and router-level "zero rows for unauthenticated traffic" auth ordering — both now pinned in sections D/E |
| `Xaas.Sa2a.Generated.McpDescriptor` | `lib/xaas/generated/sa2a_mcp_descriptor.ex` | COVERED (indirect): `test/xaas/sa2a/bridge_authority_chicago_test.exs` (different family: SA2A bridge surface; out of lane scope, no court needed) |

## Court

`test/xaas_web/mcp/family_court_w984gp_test.exs` — 8 tests, real ConnCase
through the real endpoint/router into `AshAi.Mcp.Router`, real
`INTERNAL_API_TOKEN` bearer per existing convention, real sandboxed
Postgres, zero mocks. Per-test mutation rationale in-file:

- A. `McpDescriptor.describe/1` exact descriptor map + `:error` for
  unregistered id (mutation: field deletion / fetch fallback).
- B. `requires_authority?/1` fail-closed `:error -> true` branch +
  registered values incl. the consequential `:checkout` row (mutation:
  flip the deny-by-default branch).
- C. Real `initialize` + `tools/list` over `POST /mcp` returns exactly
  the descriptor's `exposed_via: :mcp` ids — only pin of the generated
  `XaasWeb.McpScope.mount/0` ↔ `McpDescriptor` tool-set contract.
- D. No bearer / wrong bearer / `Basic` scheme → 401 standard envelope
  AND zero `mcp.tool_call.invoked` audit rows (mutation: audit plug
  reordered ahead of the auth plug, or bearer parsing loosened).
- E. Authenticated `/mcp?lane=w984gp` writes exactly one row whose
  metadata records method/path/query_string and the SHA-256-hex caller
  hash (mutation: metadata key dropped from plug).

## Gates (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gp \
  mix test test/xaas_web/mcp/family_court_w984gp_test.exs
→ "8 passed"  (Result: 8 passed, Finished in 1.6s, exit 0)

mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
→ []
```

Note: a mid-lane edit to this court file landed from outside the lane
(`import Ash.Expr` + `expr/1` conversion of the filter) and broke
`Ash.Query.filter/2` invocation (missing `require Ash.Query`); repaired
in-lane by adding `require Ash.Query`. Disclosed as a cross-lane touch
on a lane-owned file; final state compiles and passes.

## Cleanup

`rm -rf _build-laneW984gp` succeeded (rm exit 0; directory confirmed
absent on disk).

NO commit made.
