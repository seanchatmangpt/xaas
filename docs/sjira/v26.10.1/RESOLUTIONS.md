# Resolved seams — Monday demo fan-out (coordinator, 2026-10-01)

Binding for all lanes. Conflicts below are resolved; do not renegotiate in-lane.

## R1 — Projection artifact set
All four projections are JSON at `priv/chicago/chicago.{machine,verification,executive,replay}.json`
in xaas (pack self-test renders to `generated/chicago.*.json`). `projections.ttl` now says
`sj:extension "json"` (L1 applied). Consumer surfaces `.md`-shaped narrative INSIDE executive JSON,
not as separate files.

## R2 — Machine JSON schema (L2 emits; L4 maps; L3 gates)
Header (all four outputs): `"generated": true`, `"authorityClaim": "NONE"`, `"subject":
"urn:chicago:agentic-payment:purchase-001"`, `"projectionType": machine|verification|executive|replay`,
`"sourceDigests": [{"path": "...", "sha256": "<64hex>"}...]`, `"generatorIdentity":
"ggen-marketplace/chicago-xaas-surface-pack@26.10.1"`.
Machine body: `"rootGoal": {identifier,label,repository,baseSha,authorityCeiling,evidenceHorizon,replayIdentity}`,
`"layers": [{id (contract slug sjira|graphlaw|sa2a|pplan|xaas|ex4pm|beam4pm|affidavit|ashsurface|marketplace),
identifier,label,repository,pathScope,boundaryClass,authorityCeiling,capabilityId,evidenceHorizon,required,status,
evidenceRefs,receiptRefs}]` (status defaults `"UNKNOWN"` — no inherited standing), `"cases": [{id,label,description,
subject,candidateOnly,authorityClaim,observedStanding}]`.
Source graph note: `sj:subject` objects are now the exact LITERAL string (L1 fix); root IRI is
`chi:purchase-001` with `dcterms:identifier`. Layer IRIs are `chi:layer-{sjira,graphlaw,sa2a,pplan,xaas,ocel,beam4pm,affidavit,surface,marketplace,wasm4pm,castle}`
(contract ids ex4pm↔ocel, ashsurface↔surface).

## R3 — Executive JSON schema
L9's schema (its wave-1 report) is the emit target: narrative{audience,headline,customerProblem,desiredOutcome,semanticPath},
capabilities[] (10 required + wasm4pm/castle successor), demonstrated[] (layer ids with input ALIVE receipt ONLY),
scenarios[] (CHI-CASE-001..010 with polarity), authorityBoundaries[], failureRecovery[] (per case), evidence[]
(layer-keyed, standing UNKNOWN until real receipt), deliveryState{requiredLayers:10,demonstratedLayers,candidateLayers,successorLayers,overallStanding}.
Narrative prose facts live in pack `source/narrative.ttl` (graph, not template constants).

## R4 — Xaas.Chicago API (L4 owns lib/xaas/chicago/**)
- `Xaas.Chicago`: subject/0, machine/0, verification/0, executive/0, replay/0, layers/0, layer/1,
  required_layers/0, cases/0, case/1, reload/0 — all `{:ok,_}|{:refused,{:chicago_*,reason}}`.
- `Xaas.Chicago.View.drill_down/0` → L6's exact shape (subject, business_outcome{headline,detail,standing},
  layers[10]: id,label,what_happened,standing,lifecycle(:candidate|:admitted|:executed|:refused|:unknown),
  evidence[],receipt,absence). All layers default lifecycle :candidate / standing UNKNOWN.
- `Xaas.Chicago.Court.decide/2` (case params) + `reconcile/1`: typed refusal VALUES
  `{:refused, atom, details}` with atoms exactly: `:above_delegated_limit | :wrong_principal |
  :delegation_expired | :provider_unavailable | :unknown_after_dispatch | :missing_evidence |
  :stale_subject | :policy_drift | :authority_none`. Deterministic, in-memory, never promotes standing.
- L5 folds real runtime state (Xaas.Ultracode.*, Xaas.Ocel.*) itself; Chicago API is the projection side.

## R5 — Pack gates (L3 owns gates/ + test/ in pack)
`gates/NNN_name.rq` SPARQL ASK true=violation (marketplace admits only .rq/.py in gates/), witnessed
corpus pass/fail per gate (same-stem), `gate-court.toml` at pack root (L2 places it), typed refusals
REFUSED_CHICAGO_*, byte-identity double-render court. JSON courts target R2/R3 field names.

## R6 — Routes (coordinator applies; lanes do NOT touch router.ex)
Public `:browser` scope (wd-fa precedent, read-only observation surfaces): `live "/chicago",
Chicago.DrillDownLive` and `live "/chicago/seller", Chicago.SellerLive`.
`/system` (CommandCenterLive) goes inside the `dev_routes` block (auth discipline; Monday demo runs
with dev routes enabled locally). Internal token floor untouched.

## R7 — mix.exs (coordinator applies)
`{:ash_surface, path: "../ash_surface", only: [:dev, :test]}` + alias `"chicago.render":
["xaas.chicago.render"]`. No config/*.exs changes. No ash_domains change (L4 is plain modules).

## R8 — Standing law
Every rendered standing is UNKNOWN until a real receipt binds observed execution. No `:contained`/
pradyot-style pre-judged outcomes in any lane file. Cases stay candidate predictions.

## R9 — Concurrent writers
`~/ggen-marketplace` has an active external writer (spark-closure-courts). L2/L3 write ONLY the new
pack dir; coordinator commits explicit-path; marketplace push deferred if writer active.
`origin/feat/pradyot-monday-surface-v26.10.1` is read-only to all lanes; reconciliation is a
coordinator decision AFTER this run (its hardcoded outcomes/fake receipt must not become demo source).

## R10 — Wave-2 lane verification
Xaas lanes: `MIX_BUILD_ROOT=_build-lane<N> mix compile` + targeted `mix test <owned paths>`; route-level
LiveView tests may run at integration (router lands with lanes). No git by lanes. Report commands+exits.
