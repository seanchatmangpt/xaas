# Semantic Jira work orders — v26.9.22

Open work orders continuing the v26.9.21 cycle. Protocol unchanged from
`../v26.9.21/README.md`: real collaborators only (Chicago-style, no mocks),
work in your own worktree at the order's `base_sha`, receipts over assertions,
standing vocabulary `UNKNOWN | PARTIAL_ALIVE | ALIVE | BLOCKED | BUILD_BROKEN
| UNSUPPORTED`; `ALIVE` needs an observed run of the exact subject. Semantic
Jira admits and selects WorkOrders; it grants no authority and performs no
merge/publish.

## Orders

| id | order | standing | falsifier |
|---|---|---|---|
| SJ-010 | zcode-ocel-pack gets a real consumer | UNKNOWN | emitter accepts an event type absent from the generated registry; an emitted event passes the xaas court but is rejected by the zcode-generated schema |
| SJ-011 | Audit coverage for POST /internal-api/execution/mcp tool calls | UNKNOWN | a tools/call to /internal-api/execution/mcp leaves no audit row |

- **SJ-010** — successor of v26.9.21 SJ-002 (UNSUPPORTED there). Wire
  `Xaas.Telemetry.OcelAshEmitter`
  (`lib/xaas/telemetry/ocel_ash_emitter.ex`) to the zcode-ocel-pack generated
  registry so xaas-emitted OCEL validates against the zcode-generated schema
  (today: fully disjoint vocabularies, zero cross-repo reads). Evidence: a
  differential test — an emitted ash-actions event passes the
  generated-schema validator. Dependency: `zcode-cli gall-work landed on main
  (2026-09-22)`.
- **SJ-011** — apply audit coverage to POST `/internal-api/execution/mcp` tool
  calls. Today the `AuditMcpToolCall` pipeline covers only the `/mcp` AshAi
  scope — an asymmetry (`lib/xaas_web/router.ex:80-163`). Evidence: a
  `tools/call` to the execution fabric produces an audit row queryable via
  existing audit tables.

## Receipts convention

Wave receipts go to `docs/ultracode/<wave>-receipts/`, and cycle progress is
appended to `docs/ultracode/PROGRESS.md` (existing examples:
`wave-v26.9.17-receipts/`, `wave-v26.9.19-receipts/`). A receipt carries
commands + exit codes, real output, and the standing claimed. Receipt files
are append-only evidence: historical receipts are never edited, corrections
are recorded here in the cycle README instead.

## Supply correction (2026-09-22)

> The wave-v26.9.17 receipts pin ggen_igniter feat/calver-ticket-day-pack@d018ed4; that branch no longer exists. Current ggen_igniter line: feat/zcode-ocel-pack@f81cf54 (pack content survives there; priv/ggen/calver-ticket-day-pack + priv/ggen/semantic-jira-pack present on HEAD). Re-pin future manufacturing to a live ref.

This README is the correction record. The v26.9.17 receipt files are
historical evidence and are NOT edited to match; new manufacturing re-pins to
the live ref above.

## Files

- `SJ-010-zcode-ocel-pack-consumer.md`, `SJ-011-execution-mcp-audit-coverage.md` — one WorkOrder each (JSON front matter = the admitted field set).
- `index.json` — machine index.
