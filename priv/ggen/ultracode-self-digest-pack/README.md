# ultracode-self-digest-pack (xaas project pack)

Consumer-owned semantic capital for the self-dogfood loop
($U_t \in Subjects(U_t)$, GC-26927-SELFDIGEST):

```
Work → Resolution → Execution → OCEL → Experience → Gap → Work_self → U_{t+1}
```

**Ontology is the constitution; Ash is the executable state.** Everything the
Ash layer expresses — the WorkOrder/ExperienceCluster/Gap/Resolution/Episode
resources, the closed vocabularies (G-table classes, primitive targets,
frontier outcomes, statuses), the recurrence threshold, the G-table itself —
is an RDF fact in `ontology.ttl`, manufactured into xaas by ASH'S OWN
generators via a thin bridge. No Ash DSL is hand-written anywhere.

```
ontology.ttl ──SPARQL──▶ xaas.ash.gen ──composes──▶ ash.gen.enum / ash.gen.resource / ash.extend postgres
     │                                                                       │
     └──SPARQL──▶ ggen_igniter.sync ──▶ lib/xaas/generated/capital_census/facts.ex
                                                             │
                                    lib/xaas/.../self_digest_law.ex (ledgered law over the facts)
                                                             │
                                    AshOban digest trigger (REMAINING increment)
```

## Manufacture (regenerate everything)

```bash
mix xaas.ash.gen --ontology priv/ggen/ultracode-self-digest-pack/ontology.ttl --yes
mix ggen_igniter.sync \
  --ontology priv/ggen/ultracode-self-digest-pack/ontology.ttl \
  --query g_table=priv/ggen/ultracode-self-digest-pack/queries/g_table.rq \
  --query facts=priv/ggen/ultracode-self-digest-pack/queries/facts.rq \
  --query facts_spec=priv/ggen/ultracode-self-digest-pack/queries/facts_spec.rq \
  --query frontier_outcomes=priv/ggen/ultracode-self-digest-pack/queries/frontier_outcomes.rq \
  --template priv/ggen/ultracode-self-digest-pack/templates/facts.ex.eex --yes
mix ash.codegen add_capital_census_self_digest
git diff --exit-code   # regeneration court: zero diff or REFUSED
```

## Why a project pack, not a marketplace pack

This pack is the xaas app's OWN manufacturing source (app surface, 産面). It
would be a category error to admit it into ggen-marketplace: the G-table
individuals, the frontier outcome set and the classified shapes are xaas-loop
facts, not general capability. The GENERAL capability proved here — "ontology
facts → Ash's own igniter generators" — is the reusable part (`xaas.ash.gen`,
currently xaas-side; promotion to the marketplace as a generic bridge is a
separate, later admission).

## Pack-search ledger (REUSE → COMPOSE → EXTEND → INVENT, run 2026-09-27)

Every Ash-adjacent pack was inspected before authoring this one:

| pack | why NOT reused (failed edge) |
|---|---|
| `beam4pm-process-model-pack` (v0.1.19) | Its Ash leg projects `bpm:RecordType` field rows into attribute-only resources (+ Ets roundtrip tests). No relationships, no accept-listed actions, no provenance constraints. COMPOSED its method instead: ontology-typed attribute vocabulary, oxigraph plain-lexical values, refusal-by-name on unbound vocabulary, generated Chicago tests. |
| `ash-revops-structural-factory-pack` | Tera structural factory: attributes + empty domain stubs only. |
| `ash-runtime-integration-contract-pack` | Renders a `defaults [:read]` resource skeleton; boundary-contract family, not domain manufacture. |
| `ashdspy-pack` / `ash-ocel-revops-surface-factory-pack` / `ash-extension-pack` / `ash-r2rml-*` / `xaas-ash-core-pack` | Other capability families (DSpy lattices, OCEL surfaces, Spark extensions, R2RML mappings, xaas core scripts). `ash_r2rml`'s `gen.semantic_types` is types-only and CONSTRUCT-only by its own notice. |
| raw `ash.gen.resource` | Manufactures resources but cannot express closed vocabularies as enums, or know which resources/attributes exist — it needs a caller that owns the semantics. That caller is this pack + bridge. |

Conclusion: no admitted pack manufactures Ash DOMAIN resources (attributes +
relationships + enum-typed vocabularies + provenance constraints) from
ontology facts. INVENT is lawful here — composed with Ash's own generators so
every future family converges on the same Ash-native path instead of each
re-implementing a renderer.

## Naming failed edge

`Experience` is already owned by `Xaas.Ultracode.CapitalCensus.Experience`
(the pure-function machine-experience law, GC-26926-CENSUS). The digest
episode resource is therefore `CapitalCensus.Episode`. Shadowing the census
module would have been a silent semantic merge — refused. Subsumption of the
census law into the Ash spine is a later increment.

## Standing

See `qualification/QUALIFICATION.md` (court commands + observed results +
typed residuals).
