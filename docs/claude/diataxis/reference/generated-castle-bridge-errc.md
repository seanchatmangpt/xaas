# Generated CASTLE ↔ XaaS ERRC

> Generated from `ggen-marketplace/xaas-castle-bridge-pack`; do not hand-edit.

| ERRC | Priority | Decision | Why | Leverage |
|---|---:|---|---|---:|
| CREATE | 10 | reusable external-consequence control-plane composition | general pattern: outer durable admission/checkpoint + inner BRCE kernel + nested receipt DAG | 10 |
| CREATE | 20 | crash-recoverable nested receipt DAG | retry verifies content-addressed evidence before considering any second DO | 10 |
| CREATE | 30 | marketplace innovation composition profile | bridge composes leverage, option-capital, replay, lineage, consequence IR, causality, certification and Chicago-test packs | 9.9 |
| ELIMINATE | 10 | duplicate CASTLE PaaS Ash resource plane inside XaaS | XaaS already owns 69 Ash resources and seven domains; compose through the native RouteCastle capability instead | 9.8 |
| ELIMINATE | 20 | ambient provider command or program input | server-owned adapter profiles only; graph/model/API data never receives shell authority | 9.7 |
| ELIMINATE | 30 | fiction that Postgres rollback reverses external BRCE consequences | external DO uses durable construct checkpoint plus content-addressed CASTLE evidence recovery | 10 |
| RAISE | 10 | exact supplier identity binding | contract pins CASTLE PaaS source, CASTLE PaaS pack and ash_r2rml source identities | 9.5 |
| RAISE | 20 | receipt nesting and replay evidence | outer XaaS intent/receipt binds the inner CASTLE construct, PREPARE/OUTCOME receipts and durable evidence identity | 10 |
| RAISE | 30 | ggen-marketplace share of implementation | static contracts, topology, proof obligations, ERRC, docs and tests are manufactured rather than handwritten | 9.8 |
| REDUCE | 10 | handwritten immutable bridge identity and topology | ggen manufactures contract, edge catalog, SHACL, ERRC and proof surfaces from one RDF source | 9.6 |
| REDUCE | 20 | public mutation surface | RouteCastleRun remains read-only on JSON:API/GraphQL; execute stays private behind Reactor context | 9.4 |
| REDUCE | 30 | private semantic vocabulary standing | bridge runtime identities project to published PROV-O, ODRL, DCAT, DCTERMS, SKOS, SOSA, SHACL, ORG and Schema.org IRIs | 8.9 |


The bridge preserves the native XaaS `RouteCastleRun` capability and XaaS outer admission/receipt machinery while delegating only the nested provider consequence to CASTLE BRCE. Public semantic projection is descriptive and never grants DO authority.

## SIBLING generated projections coverage (W849 census)

Census of the repo's other GENERATED surfaces
(receipt: `docs/sjira/v26.10.6/plans/w849-generated-surface-census.md`):

| Surface | Provenance | Drift check | Class |
|---|---|---|---|
| `lib/xaas/generated/castle_bridge_{contract,edges}.ex` | ggen-marketplace/xaas-castle-bridge-pack | sha256 pin, `test/xaas/generated/registry_drift_guard_test.exs` | DRIFT-CHECKED |
| `lib/xaas/generated/sa2a_bridge_{contract,edges}.ex`, `sa2a_mcp_descriptor.ex` | sa2a-bridge-pack (ggen_igniter) | sha256 pin, same guard (W810 pin) | DRIFT-CHECKED |
| `lib/xaas/generated/zcode_event_registry.ex` | ggen_igniter, `priv/packs/xaas_zcode_ocel_pack` | sha256 pin + regen command, same guard | DRIFT-CHECKED |
| `assets/js/ash_rpc.ts`, `assets/js/ash_types.ts` | `mix ash_typescript.codegen` | regen-and-byte-compare court (W837) | DRIFT-CHECKED |
| this page | ggen-marketplace/xaas-castle-bridge-pack | `ggen sync`; W754 faithful-projection verification | DRIFT-CHECKED |
| `lib/xaas_web/mcp_scope.ex` | `priv/ggen_igniter/mcp_a2a/xaas-surface.ttl` | none | PROVENANCE-ONLY |
| `lib/mix/tasks/xaas.library.manufacture.ex` | ggen_igniter, `priv/packs/xaas_library_pack` | none | PROVENANCE-ONLY |
| `lib/xaas/generated/capital_census/facts.ex` | ultracode-self-digest-pack (ggen_igniter) | none | PROVENANCE-ONLY |
| `lib/xaas/telemetry/ocel_envelope.ex` | ggen_igniter, `priv/packs/xaas_telemetry_pack` | none | PROVENANCE-ONLY |

8 DRIFT-CHECKED / 4 PROVENANCE-ONLY / 0 UNPINNED. The registry guard is a sha256 pin, not
regen-and-compare; ontology-source conformance remains an open CI/regen leg (P2-2).
