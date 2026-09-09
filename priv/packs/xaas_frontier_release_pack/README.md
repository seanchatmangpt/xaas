# xaas_frontier_release_pack

This is the XaaS product/control-plane consumer of the ecosystem Frontier Release Factory.

It defines three persistent semantic surfaces:

1. `SourceRelease` — observed external release identity, provenance, digest, and extracted claims.
2. `Opportunity` — bounded SELECT output: response mode, target repo/capability, benchmark, acceptance predicate, and falsifier.
3. `LaunchPacket` — working-backwards or earned release packet. An earned packet cannot acquire ALIVE standing without exact subject, verifier, evidence, and replay identities.

## Manufacture

The ontology declares `agp:CodegenTarget` entries for the `Xaas.FrontierRelease` Ash domain and its three resources. The lawful implementation path is:

```text
ontology.ttl -> ggen_igniter -> ash.gen.domain/resource -> generated Ash projection
```

Do not hand-write the corresponding Ash resources to bypass a missing generator run. This PR intentionally commits only manufacturing source; generated output must be added by an observed `ggen_igniter` execution before this slice can be called implemented/ALIVE.

## Authority

RSS/article ingestion is observation. Semantic extraction is candidate construction. Opportunity selection is SELECT. Repository creation, deployment, publication, and other external mutations remain DO and must route through the existing XaaS actuation/BRCE authority boundary.

The source article, LLM interpretation, working-backwards release, or generated resource never grants DO authority.
