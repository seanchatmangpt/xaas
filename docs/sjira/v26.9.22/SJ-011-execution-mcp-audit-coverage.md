---
{
  "identity": "SJ-011",
  "title": "Audit coverage for POST /internal-api/execution/mcp tool calls",
  "description": "Apply audit coverage to POST /internal-api/execution/mcp tool calls. Today XaasWeb.Plugs.AuditMcpToolCall is piped only on the /mcp AshAi scope (lib/xaas_web/router.ex:154-163); the execution fabric's stateless MCP endpoint (lib/xaas_web/router.ex:95) pipes only [:api, :require_internal_api_token] -- an asymmetry: execution-fabric tool calls leave no audit row at all.",
  "subject": "execution-mcp-audit-coverage",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "2d229c272c3a02dcb8e75ff600ea0a4edc058d71",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.22-sj-011",
  "required_courts": [
    "compile",
    "tests",
    "chicago_no_mocks"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "a tools/call to the execution fabric produces an audit row queryable via existing audit tables",
    "execution-mcp audit rows carry the same fidelity as /mcp rows (which bearer token, which path, when)"
  ],
  "falsifiers": [
    "a tools/call to /internal-api/execution/mcp leaves no audit row",
    "coverage claimed without an observed request through the real endpoint"
  ],
  "projections": [
    "jira",
    "verification",
    "receipt"
  ],
  "dependencies": [],
  "authority_requirement": "NONE",
  "path_scope": [
    "lib/xaas_web/router.ex",
    "lib/xaas_web/plugs/**",
    "lib/xaas/operations/**",
    "test/xaas_web/**"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-011: Audit coverage for POST /internal-api/execution/mcp tool calls

- **Standing**: UNKNOWN

## Status
UNKNOWN
- **Repository**: seanchatmangpt/xaas @ `2d229c2`

## Description
Apply audit coverage to POST /internal-api/execution/mcp tool calls. Today XaasWeb.Plugs.AuditMcpToolCall is piped only on the /mcp AshAi scope (`lib/xaas_web/router.ex:154-163`); the execution fabric's stateless MCP endpoint (`lib/xaas_web/router.ex:95`) pipes only `[:api, :require_internal_api_token]` -- an asymmetry: execution-fabric tool calls leave no audit row at all.

## Evidence
- `/internal-api` scope (`lib/xaas_web/router.ex:80-113`) registers `post("/execution/mcp", ExecutionFabricController, :mcp)` with no audit plug in its pipeline
- `:audit_mcp_tool_call` appears only on the `/mcp` scope (`lib/xaas_web/router.ex:154-163`); the plug (`lib/xaas_web/plugs/audit_mcp_tool_call.ex`) writes one `Xaas.Operations.AuditLogEntry` row per `/mcp` HTTP request (rationale recorded at `lib/xaas_web/router.ex:135-142`)

## Definition of done
- [ ] a tools/call to the execution fabric produces an audit row queryable via existing audit tables
- [ ] execution-mcp audit rows carry the same fidelity as /mcp rows (which bearer token, which path, when)

Runnable check:

```sh
cd ~/xaas && mix test test/xaas_web/execution_fabric_controller_test.exs test/xaas_web/plugs
```

## Falsifiers
- a tools/call to /internal-api/execution/mcp leaves no audit row
- coverage claimed without an observed request through the real endpoint
