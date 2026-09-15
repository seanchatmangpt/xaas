# HANDWRITTEN.md — hand-written product-surface ledger

Contract: every hand-written product artifact names its missing capability and
intended owner pack, and the ledger shrinks monotonically per milestone.

Format: `path | semantic element | missing capability | intended owner pack | date`

## Active

lib/xaas/ultracode/lease.ex | ActuationLease kernel over Run/Epoch/Receipt | no admitted pack expresses a lease/claim/admit/close edge on the Ultracode seam | ggen-marketplace ultracode-actuation-lease-pack (admit from this proven shape) | 2026-09-15

lib/xaas_web/controllers/execution_fabric_controller.ex | MCP JSON-RPC + hook HTTP transport | no admitted pack renders a stateless MCP server controller inside Phoenix with internal-token gate | ggen-ecosystem-mcp-surface-pack family extension | 2026-09-15

priv/templates/zcode_plugin/** | ZCode plugin projection templates | no admitted pack owns ZCode plugin topology (plugin.json/hooks/commands/skills/agents) | zcode-plugin-pack (admit after live qualification against ZCode 3.11.2) | 2026-09-15

lib/mix/tasks/xaas.gen_zcode_plugin.ex | plugin projection generator | same as above; generator becomes the pack's render step | zcode-plugin-pack | 2026-09-15

test/xaas/ultracode/lease_test.exs | lease-edge qualification tests | no admitted gate pack for lease semantics | ultracode-actuation-lease-pack gates/ | 2026-09-15

## Paydown plan

1. Qualify the rendered plugin against ZCode 3.11.2 live (hook event names,
   plugin-root expansion variable, .mcp.json env-header support).
2. Promote templates + generator into `ggen-marketplace` as
   `zcode-plugin-pack` once qualified; delete the repo-local generator in
   favor of the pack's render step.
3. Extract the lease kernel's invariants into `ultracode-actuation-lease-pack`
   (SHACL + Ash render targets), including the bulk_update
   extracted-filter guard as a gate.
4. beam4pm integration is an ontology fact, not code: execution-provider
   observation + PlannerLease≠ActuationLease axiom in beam4pm's ontology.

## Shrunk

(none yet — baseline established 2026-09-15; note: the first attempt at
this change invented parallel ExecutionWorker/WorkContract/Execution
resources and was reverted — `backup/execution-fabric-v1` — in favor of
extending the existing Ultracode seam)
