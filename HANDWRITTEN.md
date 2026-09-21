# HANDWRITTEN.md — hand-written product-surface ledger

Contract: every hand-written product artifact names its missing capability and
intended owner pack, and the ledger shrinks monotonically per milestone.

Format: `path | semantic element | missing capability | intended owner pack | date`

## Active

lib/xaas/sa2a/bridge.ex | `Xaas.Sa2a.Bridge` GenServer: `Port.open/2` process wrapper (`{:line, ...}` framing to match autofde-lab's newline-delimited JSON-lines stdio protocol) + `validate/1`, `admit/2`, `plan/2`, `execute/2`, `replay/2` public functions calling it (2026-09-20) | no admitted pack renders a Port GenServer wrapper or its JSON-lines encode/decode; `sa2a-bridge-pack`'s ontology names this module by string (`s2b:fromPlane "Xaas.Sa2a.Bridge.execute"` etc.) without generating it, the same construct-only boundary `xaas-castle-bridge-pack` observes for `Xaas.Castle.Reactor` | ggen-marketplace sa2a-bridge-pack (admit from this proven shape) | 2026-09-20

lib/xaas/ultracode/lease.ex | ActuationLease kernel over Run/Epoch/Receipt, incl. the Receipt `:for_epoch` lawful read carve-out (2026-09-17), + `actuate/2`: a live lease's admitted, per-provider-registry-gated reach into `Xaas.Actuation.run/4` (2026-09-17) | no admitted pack expresses a lease/claim/admit/close edge on the Ultracode seam, nor its registry-gated bridge onto the separate Path-A actuation kernel | ggen-marketplace ultracode-actuation-lease-pack (admit from this proven shape) | 2026-09-17

lib/xaas_web/controllers/execution_fabric_controller.ex | MCP JSON-RPC + hook HTTP transport + sealed-receipt read route (GET /internal-api/execution/epochs/:epoch_id/receipts) + atom-safe refuse-reason mapping + `actuate` MCP tool (ZCode-UI-as-actuator seam, forwards to `Lease.actuate/2`) (2026-09-17) | no admitted pack renders a stateless MCP server controller inside Phoenix with internal-token gate | ggen-ecosystem-mcp-surface-pack family extension | 2026-09-17

lib/mix/tasks/xaas.receipts.ex | operator sealed-receipt inspection task over the authorized `:for_epoch` path | no admitted pack renders an operator receipt-read task on the Run/Epoch/Receipt seam | ultracode-actuation-lease-pack | 2026-09-17

priv/zcode_plugin/templates/script-xaas-gate.mjs.tmpl | PreToolUse host gate: admit_tool call, argv Bash allowlist (GIT_SUBS, READ_HELPERS), worktree write containment, credential-dir read denylist, zcode->server tool map (2026-09-18) | no admitted pack renders a policy-enforcement hook script from admission-ontology facts; the allowlists are constants in the script, not ontology individuals | zcode-plugin-pack (lift the constants into zp:AllowedTool / zp:AllowedBashVerb / zp:DeniedPath individuals and render the script from them) | 2026-09-18

priv/zcode_plugin/templates/script-xaas-lease.mjs.tmpl | client-side lease state file protocol (save/get/clear, conflict refusal) | no admitted pack expresses a lease state-file protocol | ultracode-actuation-lease-pack | 2026-09-15

priv/zcode_plugin/templates/{command-xaas,agent-xaas-worker,skill-xaas-worker}.md.tmpl | worker doctrine prose bodies (frontmatter is projected from ontology.ttl) | irreducible prose: no pack models doctrine text as ontology fragments | zcode-plugin-pack doctrine fragments | 2026-09-15

scripts/xaas-glm-failover-dispatcher.sh, scripts/install-glm-failover-launchd.sh | unattended failover dispatcher (poll, drain, reaper, timeout, stall alert) and its launchd installer (2026-09-18) | no admitted pack renders a provider-failover dispatcher or a launchd unit from the Run/Epoch seam | ultracode-actuation-lease-pack | 2026-09-18

test/xaas/zcode_plugin/*.exs | gate, lease-script, doctrine and projection-drift qualification tests | no admitted gate pack for plugin-projection qualification | zcode-plugin-pack gates/ | 2026-09-18

lib/xaas/ultracode/verifier.ex | fabric-executed verifier suite runner: name-only registry lookup, worktree containment root, env allowlist through `env -i`, process-group kill, bounded output, clean-tree and head discipline (2026-09-18) | no admitted pack renders a fixed-argv suite runner with these fences from the Run/Epoch seam | ultracode-actuation-lease-pack (verifier gate) | 2026-09-18

lib/xaas/ultracode/autonomic.ex, lib/mix/tasks/xaas.autonomic.run.ex | autonomic loop controller: deterministic backlog sensing, per-item worktree/ticket/Run/Epoch planning, top-up pacing that halves on provider rate refusal, fabric-verified repair loop, serialized --no-ff promotion, canonical verification at the integration head, ndjson ledger and terminal receipt (2026-09-18) | no admitted pack renders a closed-loop controller over the Run/Epoch/Receipt seam; nearest prior art is repository-factory-scheduler-pack (PLAN_ONLY) and autofde-lab autonomic-loop doctrine (stage 4 UNKNOWN) | ultracode-actuation-lease-pack + a scheduler pack promoted from this shape | 2026-09-18

lib/mix/tasks/xaas.autonomic.controls.ex | live negative-control harness: crafted bad candidates closed over the real HTTP MCP surface, sealed receipts compared to expected typed gate failures (2026-09-18) | no admitted pack renders falsifier fixtures for a definition-of-done court; nearest prior art is gate-vacuity-court-pack's executable falsifier template | a `chicago-dod-court-pack` (falsifier fixtures generated from the gate catalogue) | 2026-09-18

lib/xaas/ultracode/worktrees.ex | operator-side worktree provisioning from a registered repo alias + base_sha under a containment root | no admitted pack renders worktree provisioning for the Epoch seam | ultracode-actuation-lease-pack | 2026-09-18

priv/verifiers/aps_dod_court.py, priv/verifiers/aps_backlog.py | APS Chicago-TDD definition-of-done court (exact-head, scope, mock, assertion, canonical gates, mutation kill) and deterministic backlog derivation; receipts conform to APS evidence-receipt.schema.json | no admitted pack renders a Python-repo DoD court or mutant catalogue; nearest prior art is autofde-lab `run_chicago_qualification.py` and gate-vacuity-court-pack | a `chicago-dod-court-pack` lifted from autofde-lab CHI-* gates | 2026-09-18

priv/verifiers/tests/*.py, test/xaas/ultracode/{verifier,lease_verifier,worktrees}_test.exs | qualification of the verifier, close integration, provisioning, court and backlog | no admitted gate pack for verifier qualification | ultracode-actuation-lease-pack gates/ | 2026-09-18

test/xaas/ultracode/lease_test.exs | lease-edge qualification tests, + `actuate/2` registry-admission/refusal/authority-evidence tests (2026-09-17) | no admitted gate pack for lease semantics | ultracode-actuation-lease-pack gates/ | 2026-09-15

lib/xaas/ultracode/semantic_receipt.ex, lib/xaas/ultracode/semantic_receipt/aps_dod.ex, lib/mix/tasks/xaas.semantic.receipt.ex | sealed-receipt export in the canonical-graph reconciler contract (canonical-JSON digest identical to the graph side's `digest_exact/1`, `bridge` echoed verbatim) and the `aps-dod` court-gate adapter that maps observed gates onto acceptance/falsifier results (2026-09-20) | no admitted pack renders the fabric-to-graph receipt projection or a court-gate-to-criterion mapping | ultracode-actuation-lease-pack | 2026-09-20

lib/xaas/ultracode/semantic_crown.ex, lib/mix/tasks/xaas.semantic.{materialize,crown}.ex | autonomics crown controller: observation, SHACL-admitted candidate, frontier, descriptor, Run/Epoch, worker, sealed receipt, ledger transition, dependent unlock, fresh-process replay and a live negative control, driving the graph side as real `mix semantic_jira.*` processes (2026-09-20) | no admitted pack renders a cross-system loop controller | ultracode-actuation-lease-pack | 2026-09-20

priv/repo/migrations/20260920230000_add_semantic_bridge_to_ultracode_runs.exs, lib/xaas/ultracode/run.ex (`semantic_bridge`) | additive nullable jsonb column storing the descriptor bridge opaquely; hand-written like the sibling semantic-identity migration (no resource snapshot) (2026-09-20) | ash.codegen snapshot for the semantic-identity/bridge columns not generated | ultracode-actuation-lease-pack | 2026-09-20

test/xaas/ultracode/{semantic_receipt,semantic_crown}_test.exs | Chicago qualification of the exporter, court adapter, materialize task and the end-to-end crown with a refused-candidate control (2026-09-20) | no admitted gate pack for the fabric-to-graph loop | ultracode-actuation-lease-pack gates/ | 2026-09-20

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
2. Promote `priv/zcode_plugin/` (ontology + templates) into
   `ggen-marketplace` as `zcode-plugin-pack` once qualified. DONE
   2026-09-18 (locally): the repo-local `xaas.gen_zcode_plugin` generator is
   deleted; `cd priv/zcode_plugin && ggen sync run` renders the plugin and
   marketplace manifests, hook config and frontmatter from `ontology.ttl`
   into the tracked `marketplace/` projection (drift-checked by
   `test/xaas/zcode_plugin/projection_test.exs`). Remaining: publish to the
   marketplace, and lift the gate's allowlist constants into the ontology.
3. Extract the lease kernel's invariants into `ultracode-actuation-lease-pack`
   (SHACL + Ash render targets), including the bulk_update
   extracted-filter guard as a gate, and (2026-09-17) the `actuate/2`
   registry-lookup + forced-authority-evidence shape as a second gate,
   distinct from the admit_tool construction/consequence fence gate.
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

Wave-5 addition (2026-09-17): "make the ZCode UI also work as the
actuator." `Xaas.Ultracode.Lease.actuate/2` + the `actuate` MCP tool give a
live-leased provider worker a second, narrower, admitted surface onto
`Xaas.Actuation.run/4` (Path A) — the same kernel
`Xaas.Marketplace.Changes.ApplyProviderStatusChange` already calls, not a
new DO path. This is explicitly NOT the "AuthorityCeiling on admit_tool"
widening the prior wave's authority-mapping receipt (`wave1-06-authority.md`)
warned against: `admit_tool/2`'s Bash/git_push/publish fence is untouched in
substance and still independently tested on the same lease token an
`actuate` call used. The new surface is gated by (a) an explicit, opt-in,
per-provider `{resource, action, subject}` registry
(`config :xaas, :ultracode_actuation_registry`, empty by default —
fail-closed, same convention as `:ultracode_provider_tools`), (b) Path A's
own unmodified admission court (`FrontierEvidence`/`CausalAdmission`), and
(c) forced, lease-provenanced, non-empty authority evidence
(`authorize?: false` always; the caller cannot supply an empty authority
map or `authorize?: true`). No production registry entries are configured
anywhere in this repo today — the surface is code-complete and tested but
inert until an operator opts a specific provider into a specific
already-Reactor-admitted action.

Adversarial-review correction, same wave (2026-09-17): a 3-lens review
(security/correctness/consistency, each finding independently re-verified
by a skeptical second pass with real reproduction, not inspection alone)
found and this pass fixed 3 real defects before landing:

1. **CRITICAL, introduced by this addition**: `actuate/2` originally
   accepted `subject_id` as raw wire input with `authorize?: false` and an
   authority map carrying no subject/org scope — any live lease of a
   registered provider could name ANY row of the registered resource, not
   just one tied to its own grant (a broken-object-level-authorization gap,
   demonstrated live by the review against this repo's own passing test).
   Fixed by removing `subject_id` from the wire contract entirely: the
   registry's third tuple element (`:no_subject` or a fixed, operator-named
   subject_id string) is now the ONLY source of the acted-on subject —
   never the caller. A regression test proves a wire-supplied `subject_id`
   is ignored and cannot redirect the actuation.
2. **MAJOR, PRE-EXISTING (not introduced this wave)**: `admit_tool/2`'s
   `cond` checked the operator-configurable `admitted_tools/1` before
   `@refused_consequence_tools`, so a misconfigured `:ultracode_provider_tools`
   entry naming "Bash"/"git_push"/"publish" could have won an earlier
   clause and silently defeated the fence — contradicting this file's own
   "the ceiling is a fence, not a configurable grant" claim, dormant today
   (no such config exists anywhere in this repo) but untested until this
   review. Fixed by reordering the `cond` so the hardcoded refusal always
   wins regardless of config; a regression test proves it. Not this wave's
   own new code, but fixed here because this wave's own moduledoc addition
   makes explicit claims about that fence's robustness.
3. **MAJOR**: the `actuate` MCP dispatch clause pattern-matched any JSON
   type for `lease_token`, so a non-string value raised an unhandled
   `FunctionClauseError` through the controller instead of a typed refusal.
   Fixed with an `is_binary` guard + fallback clause; a regression test
   proves the typed error, not a crash.

Full adversarial-review transcript: workflow run `wf_c87d7295-9a9`
(7 agents, 3 review lenses + 4 independent verify passes, all 4 raw
findings confirmed real on re-verification, all fixed before this ledger
entry was written).

lib/xaas/ultracode/target_suites.ex (`sj_program_suites/0` and helpers) | fabric verifier suites for the four Semantic Jira program targets (xaas, autofde-lab, gymact, ggen-igniter): pinned toolchain env, seed take/publish and per-run-DB `mix test` shell wrappers, Python subject-identity step, curated exclusions of tests that rewrite tracked files (2026-09-21) | no admitted pack renders a verifier-suite declaration (argv, env allowlist, timeouts, seed/partition wrappers) from a target-repo ontology fact | ultracode-actuation-lease-pack (verifier gate) + a target-suite pack promoted from this shape | 2026-09-21

lib/xaas/ultracode/repos.ex (`refresh/1`, `refresh` entry field), lib/mix/tasks/xaas.ultracode.repos.ex (`--refresh`, `--refresh-before-sense`), lib/xaas/ultracode/sensing.ex (`profile_for/1`), lib/xaas/ultracode/autonomic.ex (`derive_items/3`, refresh-before-base_sha) | non-destructive fetch + `merge --ff-only` clone refresh and the registry-name -> declared-sensing-profile binding that lets the autonomic loop sense registered repos from their own tickets (2026-09-21) | no admitted pack renders a registry-entry field, a clone-refresh state machine, or a name-to-profile resolver on the Ultracode seam | ultracode-actuation-lease-pack + a scheduler pack promoted from this shape | 2026-09-21

test/xaas/ultracode/{repos_refresh,autonomic_profile_sense,sj_program_registry}_test.exs | Chicago-style qualification of clone refresh, profile-driven sensing through `Autonomic.sense/1`, the committed dev.exs baseline for the four targets, the suite environment law and the Python subject-identity guard (2026-09-21) | no admitted gate pack for registry/suite qualification | ultracode-actuation-lease-pack gates/ | 2026-09-21

(baseline established 2026-09-15; note: the first attempt at this change
invented parallel ExecutionWorker/WorkContract/Execution resources and was
reverted — `backup/execution-fabric-v1` — in favor of extending the
existing Ultracode seam)
