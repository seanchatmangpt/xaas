# HANDWRITTEN.md — hand-written product-surface ledger

Contract: every hand-written product artifact names its missing capability and
intended owner pack, and the ledger shrinks monotonically per milestone.

Format: `path | semantic element | missing capability | intended owner pack | date`

## Active

lib/xaas/ultracode/lease.ex | ActuationLease kernel over Run/Epoch/Receipt, incl. the Receipt `:for_epoch` lawful read carve-out (2026-09-17) | no admitted pack expresses a lease/claim/admit/close edge on the Ultracode seam | ggen-marketplace ultracode-actuation-lease-pack (admit from this proven shape) | 2026-09-17

lib/xaas_web/controllers/execution_fabric_controller.ex | MCP JSON-RPC + hook HTTP transport + sealed-receipt read route (GET /internal-api/execution/epochs/:epoch_id/receipts) + atom-safe refuse-reason mapping | no admitted pack renders a stateless MCP server controller inside Phoenix with internal-token gate | ggen-ecosystem-mcp-surface-pack family extension | 2026-09-17

lib/mix/tasks/xaas.receipts.ex | operator sealed-receipt inspection task over the authorized `:for_epoch` path | no admitted pack renders an operator receipt-read task on the Run/Epoch/Receipt seam | ultracode-actuation-lease-pack | 2026-09-17

priv/templates/zcode_plugin/** | ZCode plugin projection templates | no admitted pack owns ZCode plugin topology (plugin.json/hooks/commands/skills/agents) | zcode-plugin-pack (admit after live qualification against ZCode 3.11.2) | 2026-09-15

lib/mix/tasks/xaas.gen_zcode_plugin.ex | plugin projection generator | same as above; generator becomes the pack's render step | zcode-plugin-pack | 2026-09-15

test/xaas/ultracode/lease_test.exs | lease-edge qualification tests | no admitted gate pack for lease semantics | ultracode-actuation-lease-pack gates/ | 2026-09-15

## Paydown plan

1. Qualify the rendered plugin against ZCode 3.11.2 live (hook event names,
   plugin-root expansion variable, .mcp.json env-header support).
   Partial as of 2026-09-16: MCP connectivity confirmed ALIVE end-to-end
   against a live ZCode 3.11.2-25 CLI session, via an `xaas-execution` MCP
   server registered directly in ZCode's `config.json` `mcp.servers` key.
   The plugin's own `zcode plugins install` path is still BLOCKED — not by
   an xaas-side defect, but by a confirmed ZCode 3.11.2-25 bug: install
   hardcodes an empty env-var-substitution context, so a plugin's
   bearer-token secret can never resolve at install time regardless of the
   process environment. Remaining qualification (hook event names,
   plugin-root expansion variable, .mcp.json env-header support) still
   needs the install path and is blocked pending a ZCode-side fix.
   Progress 2026-09-17 (2f49261): `.mcp.json.eex` + `plugin.json.eex`
   now source the MCP bearer token from ZCode `user_config` instead of
   the session environment, removing the xaas-side dependency on the
   broken env-var-substitution path; live install-path re-qualification
   still pending.
2. Promote templates + generator into `ggen-marketplace` as
   `zcode-plugin-pack` once qualified; delete the repo-local generator in
   favor of the pack's render step.
3. Extract the lease kernel's invariants into `ultracode-actuation-lease-pack`
   (SHACL + Ash render targets), including the bulk_update
   extracted-filter guard as a gate.
4. beam4pm integration is an ontology fact, not code: execution-provider
   observation + PlannerLease≠ActuationLease axiom in beam4pm's ontology.

## Shrunk

Format: `path | what shrunk | date`

priv/templates/zcode_plugin/hooks/post_tool_use.mjs.eex | fixed nested `event: {...}` body wrapper that didn't match the flat body execution_fabric_controller expects — hook now posts tool/tool_use_id/cwd/session_id directly (committed a11bf7a) | 2026-09-16
priv/templates/zcode_plugin/hooks/post_tool_failure.mjs.eex | fixed the same nested-vs-flat body mismatch, plus a wrong hook URL segment (was posting to `post_tool_use`, now posts to `post_tool_use_failure`) (committed a11bf7a) | 2026-09-16
priv/templates/zcode_plugin/hooks/user_prompt_submit.mjs.eex | fixed the same nested-vs-flat body mismatch (committed a11bf7a) | 2026-09-16
priv/templates/zcode_plugin/commands/xaas.md.eex | fixed `close_candidate` key name mismatch — doc told workers to send `standing`, the controller/lease contract expects `outcome` (committed a11bf7a) | 2026-09-16
priv/templates/zcode_plugin/.mcp.json.eex + .zcode-plugin/plugin.json.eex | MCP bearer token now sourced from ZCode `user_config`, not the session env — paydown item 1's install-path blocker no longer has an xaas-side dependency (committed 2f49261) | 2026-09-17

Wave-4 paydown direction (2026-09-17): the zcode-plugin-pack rows shrank
toward pack admission (templates now contract-clean + credential-correct;
remaining blocker is the ZCode-side install bug, not xaas code). The
mcp-surface controller row and the lease row grew (+atom-safe refuse
reason, +sealed-receipt read path on controller/receipt/mix-task) —
disclosed growth; owner packs unchanged; both new edges are
contract-compatible extensions of the shapes those packs admit from.

(baseline established 2026-09-15; note: the first attempt at this change
invented parallel ExecutionWorker/WorkContract/Execution resources and was
reverted — `backup/execution-fabric-v1` — in favor of extending the
existing Ultracode seam)
