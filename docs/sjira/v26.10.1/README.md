# sJira v26.10.1 — Chicago render source

Status: SOURCE_GRAPH / authority ceiling CONSTRUCT / no authored DO

This directory is the canonical XaaS-side semantic source for the v26.10.1 Chicago demo.
It is deliberately small: describe one exact Chicago world once, then let ggen-marketplace
manufacture consumer projections. XaaS remains runtime/composition. AshSurface remains the
generic human projection boundary.

## RFC binding

This graph follows the FINAL_SPEC Semantic Jira contract in
seanchatmangpt/ggen_igniter/docs/rfc/RFC-SEMANTIC-JIRA-v26.9.19.md as closed for v26.9.24.

The load-bearing rules used here are:

- canonical RDF is source; Markdown/Jira/UI/generated code are projections;
- GoalCheckpoint is semantic work authority, not a receipt or an execution;
- this directory authors no sj:WorkOrder and no sj:Receipt;
- WorkOrders, if needed, are compiler projections from admitted semantic authority;
- receipts are observations from executed consequences/courts;
- every generated projection has authorityClaim NONE;
- SELECT != CONSTRUCT != DO;
- ALIVE requires exact-subject evidence plus an independent court and durable receipt;
- predecessor or adjacent standing is never inherited;
- UNKNOWN_AFTER_DISPATCH is an outcome state to reconcile, never an ALIVE standing;
- prose, chat, generated Markdown and UI surfaces never originate code-work authority.

## Exact source binding

- XaaS source base: seanchatmangpt/xaas@593f8e1965d9f4be91e9f4cd85a2b30fa0b9205e
- ggen-marketplace observed base while defining this source:
  seanchatmangpt/ggen-marketplace@05233917e903cb64a3bfdf297d677fd404253ac2
- Semantic Jira implementation authority: ggen_igniter semantic-jira-pack
- Demo exact subject: urn:chicago:agentic-payment:purchase-001

The repository SHAs above are provenance for this source wave, not runtime standing.

## Files

- goal.ttl — root goal plus ecosystem-layer checkpoints/capability ownership.
- chicago.ttl — exact Chicago episode and candidate-only positive/negative scenarios.
- projections.ttl — desired deterministic projections, all authority NONE.
- MARKETPLACE_RENDER.md — renderer contract and current marketplace gap.

## One source, many projections

goal.ttl + chicago.ttl + projections.ttl
    -> ggen-marketplace renderer
    -> machine / verification / executive / replay projections
    -> XaaS consumer state
    -> AshSurface
    -> operator / Chicago / seller views

The important equality is subject identity, not representation identity:

Subject_sJira = Subject_SA2A = Subject_PPlan = Subject_XaaS =
Subject_OCEL = Subject_Beam4PM = Subject_Affidavit = Subject_AshSurface

If a layer cannot preserve the exact IRI, it must carry an explicit receipted projection relation.

## Required Chicago layers

The root requires evidence-bearing visibility for:

1. sJira goal/requirement state;
2. GraphLaw semantic admission/refusal;
3. SA2A capability/delegation;
4. ash_pplan / ferroplan planning;
5. XaaS runtime execution/refusal state;
6. ex4pm / ash_ex4pm OCEL evidence;
7. beam4pm process conformance/replay;
8. affidavit / ash_affidavit evidence standing;
9. ash_surface faithful human projection;
10. ggen-marketplace deterministic rendering.

wasm4pm/QRI and CASTLE are represented as successor/optional layers for this Monday demo. They
may become required without changing the subject or inventing a second Chicago world.

## Non-goals

This source does not:

- create a payment rail;
- claim a real financial transaction occurred;
- grant delegated payment authority;
- make GraphLaw, planning, process mining, evidence or UI output consequential authority;
- duplicate business logic in AshSurface;
- hand-author generated WorkOrders, receipts or seller artifacts;
- promote any layer to ALIVE by adjacency.

## Standing

The semantic source is authored here. Runtime execution and marketplace rendering are not claimed
ALIVE by this directory. The renderer gap is recorded in MARKETPLACE_RENDER.md and should be closed
at the canonical generator owner rather than by hand-writing generated Chicago artifacts.
