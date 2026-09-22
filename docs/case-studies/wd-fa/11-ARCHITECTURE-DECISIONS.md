# Architecture Decisions

## ADR-001 — Model the operating loop, not a chatbot

**Decision:** failure analysis is represented as evidence, work, disposition, verification and learning.

**Reason:** the business outcome is reduced repeated investigative work, not conversational fluency.

## ADR-002 — Candidate ranking is non-authoritative

**Decision:** statistical/ML ranking may order candidates; deterministic applicability/evidence admission establishes KNOWN/PARTIAL/UNKNOWN.

**Reason:** similarity is not root-cause proof.

## ADR-003 — Preserve engineer disposition authority

**Decision:** Friday pilot surface remains SELECT_CONSTRUCT_ONLY with ENGINEER_DISPOSITION_REQUIRED.

**Reason:** the case asks for trustworthy human-in-the-loop operation; no production authority is evidenced.

## ADR-004 — Use OCEL for process evidence

**Decision:** investigations are object-centric event processes.

**Reason:** one event may involve case, drive, lot, supplier, firmware, station and multiple evidence objects.

## ADR-005 — Graph is canonical; tickets/views are projections

**Decision:** sJira, decks, Morning Brief and generated applications do not own independent architecture truth.

**Reason:** prevents drift and repeated human reconstruction.

## ADR-006 — Use public semantics before local vocabulary

**Decision:** reuse PROV-O, ORG, SKOS, SHACL and related standards where semantics fit.

**Reason:** interoperability and reduced local ontology burden.

## ADR-007 — Generate alternate runtimes from admitted semantics

**Decision:** the Next.js/FastAPI target is manufactured, not hand-maintained as an independent application.

**Reason:** the experiment asks whether semantic work/capability infrastructure has crossed into deterministic Fortune-500 implementation.

## ADR-008 — LLM is novelty exception path

**Decision:** KNOWN cases should not depend on runtime general reasoning.

**Reason:** every formalized recurring class should reduce future intelligence demand.
