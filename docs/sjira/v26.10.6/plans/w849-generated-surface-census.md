# W849 — Generated-Surface Census (v26.10.6)

Lane W849, branch `feat/playwright-surface`, HEAD a0723bf6. Findings-only; no generated
file edited, no new court written.

## Method

Census of every repo surface carrying a `GENERATED` provenance header (grep of `lib/`,
plus `docs/claude/diataxis/reference/generated-*`), then for each: presence of generation
provenance (header + named generator/regen command) and existence of a drift check
(dedicated court or `ggen sync` coverage). Classification per W849 contract:
DRIFT-CHECKED / PROVENANCE-ONLY / UNPINNED.

## Census

| # | Surface | Generator provenance | Drift check | Class |
|---|---|---|---|---|
| 1 | `lib/xaas/generated/castle_bridge_edges.ex` | header: ggen-marketplace/xaas-castle-bridge-pack | sha256 pin, `test/xaas/generated/registry_drift_guard_test.exs` (W350 gate) | DRIFT-CHECKED |
| 2 | `lib/xaas/generated/castle_bridge_contract.ex` | same | same | DRIFT-CHECKED |
| 3 | `lib/xaas/generated/sa2a_bridge_edges.ex` (W810 pin) | header: sa2a-bridge-pack (ggen_igniter renderer) | sha256 pin, same guard | DRIFT-CHECKED |
| 4 | `lib/xaas/generated/sa2a_bridge_contract.ex` | same | same | DRIFT-CHECKED |
| 5 | `lib/xaas/generated/sa2a_mcp_descriptor.ex` | same | same | DRIFT-CHECKED |
| 6 | `lib/xaas/generated/zcode_event_registry.ex` | header: ggen_igniter from `priv/packs/xaas_zcode_ocel_pack/ontology.ttl` | sha256 pin + exact regen command, same guard | DRIFT-CHECKED |
| 7 | `assets/js/ash_rpc.ts` + `assets/js/ash_types.ts` | header; generator `mix ash_typescript.codegen` | regen-and-byte-compare court, `test/xaas_web/ts_codegen_drift_court_test.exs` (W837) | DRIFT-CHECKED |
| 8 | `docs/claude/diataxis/reference/generated-castle-bridge-errc.md` | GENERATED header (line 3), pack reference | `ggen sync` coverage; W754 verified faithful projection | DRIFT-CHECKED |
| 9 | `lib/xaas_web/mcp_scope.ex` (`XaasWeb.McpScope`) | moduledoc provenance: `priv/ggen_igniter/mcp_a2a/xaas-surface.ttl` | none found (not in registry guard's sha256 map; no dedicated court) | PROVENANCE-ONLY |
| 10 | `lib/mix/tasks/xaas.library.manufacture.ex` | header + exact regen command (`mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack`) | none found | PROVENANCE-ONLY |
| 11 | `lib/xaas/generated/capital_census/facts.ex` | header + regen command (`priv/ggen/ultracode-self-digest-pack`) | none found | PROVENANCE-ONLY |
| 12 | `lib/xaas/telemetry/ocel_envelope.ex` | header + exact regen command (`priv/packs/xaas_telemetry_pack`) | none found | PROVENANCE-ONLY |

Non-generated matches excluded: `lib/xaas/semantics/computation.ex` (evidence-class
vocabulary string), `lib/xaas/case_studies/wd_fa/stogaf*.ex` (ST-5 level literally named
"GENERATED"). No surface classifies UNPINNED: every census entry carries a generator
reference.

## Standing

- Census: 12 surfaces — 8 DRIFT-CHECKED, 4 PROVENANCE-ONLY, 0 UNPINNED.
- Registry drift guard (`registry_drift_guard_test.exs`) is a sha256 **pin** court, not
  regen-and-compare; its own header admits it detects hand-edit/regeneration drift but
  does not prove ontology-source conformance — that leg is P2-2 (CI/regen), still open.
- Only the W837 TS court does real regen-and-byte-compare.

## Backlog (gaps — courts NOT written in this lane)

1. Extend `registry_drift_guard_test.exs` sha256 map with the four PROVENANCE-ONLY
   surfaces: `mcp_scope.ex`, `xaas.library.manufacture.ex`, `capital_census/facts.ex`,
   `ocel_envelope.ex` (P2-class; mechanical).
2. P2-2: CI/regen leg proving pinned files match their ontology sources (regen in CI),
   upgrading the whole registry set from pin-based to regen-based DRIFT-CHECKED.
3. McpScope moduledoc provenance names a TTL source outside `priv/packs/` conventions;
   consider normalizing to the pack-dir regen-command form the other surfaces use.

## Falsifier

A surface classified DRIFT-CHECKED here whose court does not fail on an injected hand-edit
of its generated file (guards 1–6: sha pin; 7: byte-compare; 8: ggen sync diff), or a
PROVENANCE-ONLY surface that acquires a court without this receipt being updated.
