# W714 — sa2a-computation-boundary.md doc verification receipt

Subject: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface. Lane W714, no commit.
Target: docs/claude/diataxis/reference/sa2a-computation-boundary.md (verified against
lib/xaas/sa2a/*, lib/xaas/semantics/computation.ex, lib/xaas/ultracode/semantic_work.ex,
lib/xaas/generated/sa2a_bridge_edges.ex, config/config.exs).

## Per-claim table

| # | Claim in doc | Status | Evidence (file:line) |
|---|---|---|---|
| 1 | Boundary accepts runtime-neutral artifacts across ONNX/Nx-Axon/PyTorch/scikit-learn/LLM/rules/SPARQL/FOND/HDDL/WASM/native/human | VERIFIED | lib/xaas/semantics/computation.ex:11 (`@runtimes` closed allowlist, all 13 present) |
| 2 | ComputationArtifact names capability separately from runtime | VERIFIED | computation.ex:1-64 (`artifact_identity` vs `runtime`, `Registry.public_iri?` gate) |
| 3 | ComputationClaim always CANDIDATE, cannot authorize actuation | VERIFIED | computation.ex:154-164 (`"CANDIDATE" <- ...`, hardcoded `authorizes_actuation: false`); refusal at 167-171 |
| 4 | PlanningAdvice reorders but cannot add/remove frontier members | VERIFIED | computation.ex:202-208 moduledoc; `order_formal/2` at computation.ex:262-278 filters to formal set, appends remainder |
| 5 | Consequential mutation path: projection→admission→intent→receipt→Ash.Reactor DO→sealed receipt→replay | VERIFIED | lib/xaas/sa2a/executor.ex:6-8 moduledoc; executor.ex:51-67 routes through `Xaas.Actuation.run/4` |
| 6 | "Computation modules do not call Xaas.Actuation" | CORRECTED (clarified) | True of lib/xaas/semantics/computation.ex (zero Actuation refs); clarified that `Xaas.Sa2a.Executor` (lib/xaas/sa2a/executor.ex:59) is the sole Actuation caller in the SA2A surface, and is the control-plane route, not a computation module |
| 7 | Route: three representations (wo.json row / SA2A task / epoch contract via SemanticWork.admit/1) → one tuple | VERIFIED | lib/xaas/sa2a/route.ex:2-42 moduledoc; tuple/1 dispatch route.ex:100-127; `SemanticWork.admit/1` exists at lib/xaas/ultracode/semantic_work.ex:207 |
| 8 | Task carries one data part, schema `semantic-jira/route-tuple/v1` | VERIFIED | route.ex:48 `@route_schema`; route.ex:276-291 `task_tuple/1` (exactly-one-carrier, ambiguity refused) |
| 9 | digest = sha256 over canonical JSON (sorted keys, compact, exclusions sorted) | VERIFIED | route.ex:134-148 |
| 10 | resolve/1: `recipe:<id>` via `config :xaas, :ultracode_construction_recipes`, else `{:refused, :unregistered_capability}` | VERIFIED | route.ex:165-174; registry actually configured at config/config.exs:477 (`recipe:mix-format`) |
| 11 | conserve/3 refuses digest mismatch as `broken_term: "admission_vacuous"` | VERIFIED | route.ex:187-202; also names first differing field — detail added to doc |
| 12 | Route grants no authority / selects no frontier / actuates nothing | VERIFIED | route.ex has no Actuation/Ash refs (grep clean); read-only `Application.get_env` at route.ex:334 |
| 13 | Bridge is JSON-lines port protocol matching autofde_lab/beam/beam_port_bridge.py | UNVERIFIABLE | ~/autofde-lab checkout not present on this machine; claims rest on lib/xaas/sa2a/bridge.ex:11-17 docstring. The xaas-side half (Port.open {:line,...}, one JSON obj/line, bridge.ex:190-231) is verified |
| 14 | execute/2 sole DO edge (s2b:edge40, do_boundary?: true) | VERIFIED | lib/xaas/generated/sa2a_bridge_edges.ex:7 (sequence 40, `do_boundary?: true`, only such row) |
| 15 | Executor is autonomic only via Court → SystemAuthority → Actuation | VERIFIED | executor.ex:51-67; policy allowlist lib/xaas/sa2a/execution_policy.ex:63-85 (deny-by-default, execution_policy.ex:39-44) |

## Edits made to the doc

1. Added module locations + line anchors for ComputationArtifact/ComputationClaim/
   PlanningAdvice (claim rows 2-4), including the `order_formal/2` mechanism.
2. Clarified claim 6: computation modules call no Actuation; `Xaas.Sa2a.Executor`
   (executor.ex:59) is the sole Actuation caller and is the admitted control-plane route.
3. Added file:line anchors and two precision details to the Route paragraphs: the task
   tuple rides in exactly one `kind: "data"` part (multi-carrier refused) and conserve/3
   names the first differing field; registry config cited at config/config.exs:477.

No stale/incorrect claims beyond row 6 found; rows 13's sibling half marked UNVERIFIABLE
in place of correction (no autofde-lab checkout locally).

## Standing

PARTIAL_ALIVE — every xaas-local claim verified against code at a0723bf6; the
sibling-repo (autofde-lab beam_port_bridge.py) protocol claim is UNVERIFIABLE from
xaas alone. No build run (doc-only lane). Falsifier for the conservation claim:
`mix test test/xaas/sa2a/` (not run; doc-only lane, no commit).
