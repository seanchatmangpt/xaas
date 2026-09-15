# HANDWRITTEN.md — hand-written product-surface ledger

Contract: every hand-written product artifact names its missing capability and
intended owner pack, and the ledger shrinks monotonically per milestone.

Format: `path | semantic element | missing capability | intended owner pack | date`

## Active

lib/xaas/execution.ex | lease kernel (claim/heartbeat/admit/close) | no admitted pack expresses a receipted execution-lease domain over AshPostgres | ggen-marketplace execution-fabric-pack (to be admitted from this change's proven shape) | 2026-09-15

lib/xaas_web/controllers/execution_fabric_controller.ex | MCP JSON-RPC + hook HTTP surface | no admitted pack renders a stateless MCP server controller inside Phoenix with internal-token gate | ggen-marketplace mcp-surface-pack extension (ggen-ecosystem-mcp-surface-pack family) | 2026-09-15

priv/templates/zcode_plugin/** | ZCode plugin projection templates | no admitted pack owns ZCode plugin topology (plugin.json/hooks/commands/skills/agents) | ggen-marketplace zcode-plugin-pack (admit after live qualification against ZCode 3.11.2) | 2026-09-15

lib/mix/tasks/xaas.gen_zcode_plugin.ex | plugin projection generator | same as above; generator becomes the pack's render step | zcode-plugin-pack | 2026-09-15

test/xaas/execution_test.exs | lease-kernel qualification tests | no admitted gate pack for execution-lease semantics | execution-fabric-pack gates/ | 2026-09-15

## Paydown plan

1. Qualify the rendered plugin against ZCode 3.11.2 live (hook event names,
   plugin-root expansion variable, .mcp.json env-header support).
2. Promote the templates + generator into `ggen-marketplace` as
   `zcode-plugin-pack` (pack.toml + ontology.ttl + gates) once qualified;
   delete the repo-local generator in favor of the pack's render step.
3. Extract the lease-kernel resource schema + invariants into
   `execution-fabric-pack` (SHACL + Ash render targets), including the
   bulk_update extracted-filter guard as a gate.
4. The durable ProviderEvent resource (currently telemetry/log evidence only)
   is the next manufactured edge; owner: execution-fabric-pack.

## Shrunk

(none yet — baseline established 2026-09-15)
