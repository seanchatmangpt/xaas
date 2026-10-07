# Generated Surfaces — Provenance and Drift Census

Hand-authored. Census of generated surfaces (W849 census); see the live receipt at
`docs/sjira/v26.10.6/plans/w849-generated-surface-census.md`.

| Surface | Provenance | Drift check | Class |
|---|---|---|---|
| `lib/xaas/generated/castle_bridge_{contract,edges}.ex` | ggen-marketplace/xaas-castle-bridge-pack | sha256 pin, `test/xaas/generated/registry_drift_guard_test.exs` | DRIFT-CHECKED |
| `lib/xaas/generated/sa2a_bridge_{contract,edges}.ex`, `sa2a_mcp_descriptor.ex` | sa2a-bridge-pack (ggen_igniter) | sha256 pin, same guard (W810 pin) | DRIFT-CHECKED |
| `lib/xaas/generated/zcode_event_registry.ex` | ggen_igniter, `priv/packs/xaas_zcode_ocel_pack` | sha256 pin + regen command, same guard | DRIFT-CHECKED |
| `assets/js/ash_rpc.ts`, `assets/js/ash_types.ts` | `mix ash_typescript.codegen` | regen-and-byte-compare court (W837) | DRIFT-CHECKED |
| `generated-castle-bridge-errc.md` | ggen-marketplace/xaas-castle-bridge-pack | `ggen sync`; W754 faithful-projection verification | DRIFT-CHECKED |
| `lib/xaas_web/mcp_scope.ex` | `priv/ggen_igniter/mcp_a2a/xaas-surface.ttl` | none | PROVENANCE-ONLY |
| `lib/mix/tasks/xaas.library.manufacture.ex` | ggen_igniter, `priv/packs/xaas_library_pack` | none | PROVENANCE-ONLY |
| `lib/xaas/generated/capital_census/facts.ex` | ultracode-self-digest-pack (ggen_igniter) | none | PROVENANCE-ONLY |
| `lib/xaas/telemetry/ocel_envelope.ex` | ggen_igniter, `priv/packs/xaas_telemetry_pack` | none | PROVENANCE-ONLY |

8 DRIFT-CHECKED / 4 PROVENANCE-ONLY / 0 UNPINNED. The registry guard is a sha256 pin, not
regen-and-compare; ontology-source conformance remains an open CI/regen leg (P2-2).

Relocated from `reference/generated-castle-bridge-errc.md` (W919/W980c): the section lived
inside a ggen-generated page, where a plain `ggen sync` regen would silently delete it.
The full durable artifact lives at
`docs/cro/artifacts/generated-surface-census-v26.10.6.md`.
