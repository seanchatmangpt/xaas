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
- [`reference/ultracode-runtime-contract.md`](reference/ultracode-runtime-contract.md) — UltraCode two-port runtime law (sJira/SA2A/local/BRCE planes, worker env, falsifier).
- [`reference/eu-ai-act-semantics.md`](reference/eu-ai-act-semantics.md) — `lib/xaas/semantics/` EU-AI-Act modules: signatures, typed refusal atoms, corpus line ids, AIRo mapping.
- [`reference/standing-vocabulary.md`](reference/standing-vocabulary.md) — the closed standing-status set (ALIVE/REFUTED/BLOCKED/UNKNOWN/PARTIAL/PARTIAL_ALIVE/UNSUPPORTED/BUILD_BROKEN), ALIVE-requires-execution, standing-vs-state, `REFUSED_` refusal atoms; enforced by `CapabilityLivenessReceiptStatusGate`.

## Explanation

Conceptual architecture and rationale:

- [`explanation/ash-is-the-xaas.md`](explanation/ash-is-the-xaas.md) — **Ash Framework as the Declarative Substrate for Everything-as-a-Service**: Why modeling domain logic as data enables multi-interface convergence, atomic concurrency, and governed actuation.
- [`explanation/ontology-reactor-control-plane.md`](explanation/ontology-reactor-control-plane.md) — why semantic projection is separated from authority and why Reactor is the exclusive consequential DO path.
- [`explanation/architecture-overview.md`](explanation/architecture-overview.md) — broader system architecture.
- Existing research/design documents in this quadrant remain explanation/evidence, not operational instruction.

### Evidence and research (non-operational)

Decision records, research notes, scan reports, and design proposals. They record what was observed or decided on the date each page states; they are not operational instruction and do not grant authority.

- [`explanation/ash-typescript-adoption.md`](explanation/ash-typescript-adoption.md) — decision record: `ash_typescript` adopted, with generated TypeScript for 3 resources.
- [`explanation/ashiam-create-update-limitation.md`](explanation/ashiam-create-update-limitation.md) — root-cause note on `AshIam.Check` returning `Ash.Error.Forbidden` for `:create`/`:update` actions.
- [`explanation/beam4pm-ex4pm-dependency-decision.md`](explanation/beam4pm-ex4pm-dependency-decision.md) — decision: no mix dependency on `beam4pm`/`ex4pm`; the HTTP network boundary is the sole integration surface.
- [`explanation/errc-innovation-grid.md`](explanation/errc-innovation-grid.md) — evolving ERRC (Eliminate-Reduce-Raise-Create) grid of the real xaas feature surface.
- [`explanation/k8s-fault-scan-report.md`](explanation/k8s-fault-scan-report.md) — scan-and-report security/fault scan of the `kind-xaas` cluster (2026-08-20).
- [`explanation/ocel-egress-forwarder.md`](explanation/ocel-egress-forwarder.md) — how `Xaas.Telemetry.OcelForwarder` forwards OCEL v2 events to ex4pm/beam4pm.
- [`explanation/ontology-first-reactor-actuation.md`](explanation/ontology-first-reactor-actuation.md) — control-plane architecture introduced in v26.8.22 (ontology-first Ash resources, Reactor actuation).
- [`explanation/r2rml-ontop-prototype.md`](explanation/r2rml-ontop-prototype.md) — prototype of R2RML + Ontop virtual-graph SPARQL over the Postgres schema.
- [`explanation/reactor-autofde-planners-design.md`](explanation/reactor-autofde-planners-design.md) — proposal (unimplemented) for orchestrating autofde-lab planners from xaas via Reactor.
- [`explanation/security-and-testing-decisions.md`](explanation/security-and-testing-decisions.md) — reasoning behind the deny-by-default policy floor and Chicago-style testing in the Ash migration.
- [`explanation/wasm4pm-process-intelligence-research.md`](explanation/wasm4pm-process-intelligence-research.md) — research note (GitHub issue #19) on wasm4pm and process intelligence in Ash; implements nothing.

Reference pages not previously indexed:

- [`reference/ex4pm-ontology-pin.md`](reference/ex4pm-ontology-pin.md) — config surface behind `Xaas.Ontology.Ex4pmStaleness` and `mix xaas.telemetry.check_ontology_staleness`.
- [`reference/sa2a-computation-boundary.md`](reference/sa2a-computation-boundary.md) — SA2A computation boundary: runtime-neutral artifacts and candidate claims that cannot authorize actuation.
- [`reference/generated-castle-bridge-errc.md`](reference/generated-castle-bridge-errc.md) — generated castle-bridge ERRC page (ggen sync projection; do not hand-edit).
- [`reference/generated-surfaces.md`](reference/generated-surfaces.md) — hand-authored census of generated surfaces: provenance, drift checks, DRIFT-CHECKED / PROVENANCE-ONLY / UNPINNED classes (W849; relocated from the generated ERRC page, W919).
- [`reference/w849-census-relocate-plan.md`](reference/w849-census-relocate-plan.md) — PLAN ONLY (not executed): relocation plan for the W849 census section out of the ggen-generated ERRC page.
- [`reference/w919-census-relocate-plan.md`](reference/w919-census-relocate-plan.md) — PLAN ONLY (not executed): canonical copy of the W919 census-relocation plan at the dispatch-named path.

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
