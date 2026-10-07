# W827 — architecture-overview.md refresh receipt

- **Lane**: W827, xaas v26.10.6 campaign
- **Subject**: /Users/sac/xaas @ a0723bf6, branch `feat/playwright-surface`
- **Files written**: `docs/claude/diataxis/explanation/architecture-overview.md` (only),
  this receipt. No build root, no commit.

## Per-claim table

| # | Claim in doc | Verdict | Action / evidence |
|---|---|---|---|
| 1 | "eight lease verbs" + 8-verb list (`execution/mcp`) | **CORRECTED** | 10 verbs in code: `@mcp_tools` `name:` rows and `dispatch_tool/2` clauses both count 10 (`claim_next`, `heartbeat`, `admit_tool`, `record_provider_event`, `close_candidate`, `refuse`, `cancel_work`, `actuate`, `resolve_capability`, `surface`) — `lib/xaas_web/controllers/execution_fabric_controller.ex:72-220` (10 `name:` rows), `:423-556` (10 dispatch verbs). Matches W749 receipt row 2 (which itself corrected the brief's "8"). Doc now says ten verbs, lists all 10, notes `claim_next` is the only non-lease-token verb. |
| 2 | Ultracode domain resource count 8 (3 control-plane + 5 CapitalCensus) | **VERIFIED** | `lib/xaas/ultracode.ex:31-40` — exactly Run, Epoch, Receipt + ExperienceCluster, Gap, Resolution, WorkOrder, Episode. Unchanged. |
| 3 | `/a2a/v1` routing: `forward("/v1", XaasWeb.A2A.V1TransportPlug, ...)` inside `/a2a` scope, before `/` catch-all | **VERIFIED** | `lib/xaas_web/router.ex:221`. |
| 4 | Export endpoint missing from routing paragraph | **ADDED** | `GET /internal-api/eu-ai-act/pack` → `EuAiActExportController` — `lib/xaas_web/router.ex:95`. |
| 5 | W521 admission plug missing from cross-cutting section | **ADDED** | `XaasWeb.Plugs.EuAiActAdmissionPlug` mounted in `lib/xaas_web/endpoint.ex:100`; refuse-only Art. 5 gate on `/a2a` POSTs (moduledoc `lib/xaas_web/plugs/eu_ai_act_admission_plug.ex`). |
| 6 | W533 marking plug missing | **ADDED** | `XaasWeb.Plugs.SyntheticMarkingPlug` mounted `lib/xaas_web/endpoint.ex:99`; `x-ai-generated` header + `"ai_generated": true` body field, `register_before_send`. |
| 7 | W703 plug ordering (marking before admission) missing | **ADDED** | endpoint order `SyntheticMarkingPlug` then `EuAiActAdmissionPlug` (`lib/xaas_web/endpoint.ex:99-100`); rationale in `lib/xaas_web/plugs/synthetic_marking_plug.ex` moduledoc; court receipt `docs/sjira/v26.10.6/plans/w703-plug-order-court.md`. |
| 8 | W794 raw-body reader scope | **ADDED** | `lib/xaas_web/plugs/stripe_raw_body_reader.ex` — `@raw_body_paths = [["webhooks","stripe"], ["internal-api","sparql"]]`; wired as endpoint `:body_reader` at `lib/xaas_web/endpoint.ex:83`; covers the Ontop proxy empty-body gap. |
| 9 | OcelEnvelope validation (W702) missing | **ADDED** | `Xaas.Telemetry.OcelForwarder.do_forward/2` calls real `Ex4pm.OCEL.validate_envelope/1` before POST, refuses on error — `lib/xaas/telemetry/ocel_forwarder.ex:135-161`; envelope construction delegated to generated `Xaas.Telemetry.OcelEnvelope.build/3` (`lib/xaas/telemetry/ocel_envelope.ex:51`, generated from `priv/packs/xaas_telemetry_pack/ontology.ttl`); matches W702 receipt rows 7 & 9. |
| 10 | A2A parse floor (W150) missing | **ADDED** | `lib/xaas_web/plugs/a2a_parse_floor.ex`, mounted in endpoint before `Plug.Parsers` (`lib/xaas_web/endpoint.ex:76`) → JSON-RPC -32700 on malformed `/a2a` JSON. |
| 11 | v1 card caching contract | **ADDED** | wrapper restores `Cache-Control: public, max-age=300` on the JSON agent card — `lib/xaas_web/a2a/v1_transport_plug.ex:18-34`. |
| 12 | `/a2a` scope auth floor (token-only, no plug Auth) | **VERIFIED** | `lib/xaas_web/router.ex:202-231` (`/zoe-event`, `/v1`, `/` forwards in one token-gated scope). |

## Standing

PARTIAL_ALIVE — prose edits verified against code at a0723bf6 by direct read
(router/endpoint/controller/plug/telemetry sources); no test run needed
(documentation-only lane; no executable surface changed).
