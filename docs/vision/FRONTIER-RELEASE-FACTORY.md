# Frontier Release Factory — XaaS Product Surface

Status: **CANDIDATE / manufacturing source present; generated Ash projection not yet executed in this PR transport**.

## Purpose

XaaS is the persistent product/control surface for the ecosystem-wide Frontier Release Factory. It does not duplicate the semantic extraction, process-mining, or generated-pack responsibilities of sibling repositories.

```text
RSS / article / paper / release
  -> SourceRelease (OBSERVED)
  -> semantic extraction candidate
  -> Opportunity (SELECT)
  -> working-backwards LaunchPacket (CONSTRUCT)
  -> implementation in owning repository
  -> exact-subject verification + replay
  -> earned LaunchPacket (ALIVE only with evidence)
  -> publication through explicit DO authority
```

## Repository role split

- `chatman-ecosystem`: cross-repository policy, routing, authority and standing.
- `ggen-marketplace`: reusable Frontier Release Factory ontology/templates/gates.
- `xaas`: persistent SourceRelease / Opportunity / LaunchPacket product surface and operator visibility.
- `ex4pm`: process intelligence, conformance and cycle-time analysis over the factory trace.
- `beam4pm`: BEAM execution/process substrate and generated record/process projections.
- `ggen` / `ggen_igniter`: deterministic manufacture; neither receives publication or repository-creation authority.

## XaaS manufacturing path

Canonical input is `priv/packs/xaas_frontier_release_pack/ontology.ttl`. It declares `agp:CodegenTarget` entries for the `Xaas.FrontierRelease` Ash domain and its three resources. The corresponding Ash files must be produced by `ggen_igniter`/Ash generators; they are not to be handwritten because a generator path exists.

The first generator execution must record its exact ggen_igniter version, ontology digest, generated paths and receipts. If the generic `ash.gen.resource` projection is insufficient for required attributes/actions, extend the admitted pack/template source and regenerate rather than patch generated modules.

## Authority boundary

Observation and article retrieval do not authorize action. An LLM may propose normalized claims or an opportunity only as a candidate. Creating a GitHub repository, pushing a branch, deploying a service, publishing a release, communicating externally, or spending money is consequential DO and remains behind `Xaas.Actuation.run/4` / the owning BRCE adapter with explicit scope.

The intended automation may therefore monitor continuously without gaining ambient mutation authority.

## Working-backwards versus earned release

`working_backwards` is a target contract and may contain unearned promises. `earned` is a projection over verified evidence only. The gate refuses an `earned` ALIVE packet lacking exact subject, verifier, evidence and replay identities.

## Acceptance ladder

1. ggen_igniter executes the ontology targets and creates the domain/resources.
2. Generated files are attributable to the exact ontology/toolchain subject.
3. Real Ash actions persist a source release, opportunity and working-backwards packet under existing policy/auth boundaries.
4. A source release cannot acquire ALIVE authority standing.
5. An earned packet without evidence is refused.
6. A real verified implementation receipt can promote only its supported claim set.
7. Publication requires explicit DO authority and yields a receipt.

## Falsifiers

- A generated Ash resource is hand-edited as the authoritative fix.
- An article, LLM summary, or working-backwards packet directly triggers external DO.
- An earned release reaches ALIVE without exact-subject verifier/replay evidence.
- Replay republishes or recreates repositories instead of verifying prior consequences.
- XaaS duplicates process-intelligence or marketplace-pack semantics that already have an owning repository.
