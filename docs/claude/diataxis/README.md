# XaaS Documentation — Diátaxis Index

This directory is the canonical navigation surface for current XaaS documentation. Current behavior is defined by executable code and tests; prose records only what those surfaces support.

## Tutorials

Learning-oriented, end-to-end paths:

- [`tutorials/receipted-provider-lifecycle.md`](tutorials/receipted-provider-lifecycle.md) — exercise the provider lifecycle through the receipted Reactor path.
- [`tutorials/build-an-autonomic-capability-loop.md`](tutorials/build-an-autonomic-capability-loop.md) — existing end-to-end autonomic-capability learning path.

## How-to guides

Goal-oriented procedures:

- [`how-to/actuate-provider-lifecycle.md`](how-to/actuate-provider-lifecycle.md) — perform an admitted provider status transition and handle replay/refusal.
- [`how-to/add-a-real-json-api-route-to-an-ash-resource.md`](how-to/add-a-real-json-api-route-to-an-ash-resource.md) — safely add an Ash JSON:API route.
- [`how-to/fix-ash-admin-and-use-ggen-for-codegen.md`](how-to/fix-ash-admin-and-use-ggen-for-codegen.md) — repository-specific Ash Admin/ggen procedure.
- [`how-to/author-ggen-templates-safely.md`](how-to/author-ggen-templates-safely.md) — two real ggen/ggen_igniter template-authoring defects from the MCP/A2A dogfood run: macro bodies invalid only at a real call site, and multi-surface capability rows needing an explicit discriminator.

## Reference

Exact factual contracts:

- [`reference/actuation-and-semantics.md`](reference/actuation-and-semantics.md) — public-ontology projection, actuation, idempotency, receipts, provider lifecycle, and refusal contracts.
- [`reference/ash-configuration.md`](reference/ash-configuration.md) — Ash domains/extensions/configuration.
- [`reference/http-api-surface.md`](reference/http-api-surface.md) — current HTTP exposure and auth boundaries.

## Explanation

Conceptual architecture and rationale:

- [`explanation/ash-is-the-xaas.md`](explanation/ash-is-the-xaas.md) — **Ash Framework as the Declarative Substrate for Everything-as-a-Service**: Why modeling domain logic as data enables multi-interface convergence, atomic concurrency, and governed actuation.
- [`explanation/ontology-reactor-control-plane.md`](explanation/ontology-reactor-control-plane.md) — why semantic projection is separated from authority and why Reactor is the exclusive consequential DO path.
- [`explanation/architecture-overview.md`](explanation/architecture-overview.md) — broader system architecture.
- Existing research/design documents in this quadrant remain explanation/evidence, not operational instruction.

## Case Studies

Demonstrations of the XaaS architectural model in end-to-end applications:

- [`case-studies/next-read/README.md`](../../case-studies/next-read/README.md) — **Next Read**: Interactive, ML-ranked library recommendation system and circulation lifecycle backed by Ash resources, sentence embeddings, and reactive LiveViews.

## Capability standing rules

- **ALIVE** requires observed execution against the exact admitted subject.
- Source inspection, workflow presence, test names, and documentation are not execution proof.
- When local execution is unavailable, exact-head GitHub CI may qualify the changed subject, but only successful runs on the exact head are admitted.
- Semantic projections and generated/read models have no ambient execution authority.

## Canonical-source decisions

- Executable Ash resources/actions are authoritative for behavior.
- `Xaas.Semantics.Registry` is authoritative for public-ontology projection rules.
- `Xaas.Actuation` and its real Postgres/Reactor tests are authoritative for consequential actuation semantics.
- This index is authoritative for documentation navigation; individual pages link to, rather than duplicate, contracts owned by other quadrants.
