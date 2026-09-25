# Semantic TOGAF v26.9.22 RFC

**Status:** FINAL_SPEC — closed for v26.9.24  
**Working name:** Semantic TOGAF / STOGAF  
**Compatibility:** TOGAF-compatible semantic execution profile  
**Normative scope:** Chatman ecosystem architecture state, work, evidence, projections, governance, and learning  
**Non-claim:** This document is not an official Open Group specification.

## Abstract

Semantic TOGAF (STOGAF) treats enterprise architecture as admitted, machine-addressable state rather than a collection of documents.

The governing equation is:

```
A = μ(O*)
```

where:

- `O*` is admitted enterprise state;
- `μ` is lawful manufacture;
- `A` is an architecture artifact or projection with bounded standing.

A slide, ticket, dashboard, API, generated application, architecture diagram, work order, or daily brief is therefore not an independent source of architecture truth. It is a projection of admitted state.

The primary invariant is:

> No architecture artifact should require a human to reconstruct information that the enterprise already knows how to derive.

## 1. Problem

Traditional enterprise architecture frequently separates:

- architecture description;
- implementation work;
- runtime evidence;
- governance;
- change management;
- operational views;
- organizational learning.

The separation produces stale diagrams, tickets with hidden context, manual architecture review, unreceipted state transitions, and repeated reconstruction of knowledge already present in the enterprise.

STOGAF defines a semantic execution profile that preserves TOGAF-compatible concerns while making architecture state executable, queryable, constrained, receipted, and replayable.

## 2. Normative language

The terms **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** describe requirements of this profile.

## 3. Canonical state

The canonical architecture subject is `O*`.

`O*` MUST distinguish at least:

- Enterprise
- ArchitectureState
- Stakeholder
- Concern
- Viewpoint
- View
- Requirement
- Constraint
- Principle
- Capability
- Resource
- Organization
- Process
- Application
- Technology
- Service
- Dependency
- Decision
- Risk
- Gap
- Transition
- WorkPackage
- Plateau
- Baseline
- Target
- Evidence
- Finding
- Authority
- Verification

Architecture artifacts MUST be derivable projections of this admitted state.

## 4. Public semantic foundation

STOGAF SHOULD reuse public vocabularies where their semantics fit rather than creating application-private synonyms.

The preferred stack includes:

- RDF / RDFS / OWL
- SHACL
- PROV-O
- W3C ORG
- SKOS
- OWL-Time
- SOSA / SSN
- QUDT
- DCAT
- OCEL for object-centric event evidence

Local vocabulary is permitted only for irreducible enterprise semantics.

## 5. Core invariants

1. **Canonical-state invariant** — architecture truth resides in admitted graph state, not in a presentation artifact.
2. **Projection invariant** — Jira, dashboards, decks, APIs, diagrams and briefs are projections.
3. **Evidence invariant** — architecture claims MUST retain provenance and an evidence ceiling.
4. **Authority invariant** — planning, candidate generation and construction do not imply consequential authority.
5. **Unknown invariant** — missing evidence MUST NOT be replaced with guessed completion.
6. **Receipt invariant** — consequential transitions require receipts appropriate to their authority boundary.
7. **Replay invariant** — accepted evidence and transitions MUST be replayable against the exact subject where practical.
8. **Learning invariant** — verified consequence MAY become reusable MachineExperience only with applicability and provenance.
9. **Human-reconstruction invariant** — no artifact SHOULD force a human to manually rebuild derivable context.

## 6. TOGAF-compatible lifecycle mapping

STOGAF does not require architecture work to be a sequential document ceremony. ADM-compatible phases are modeled as architecture-state transitions and may execute iteratively or event-driven.

| Phase | STOGAF interpretation |
|---|---|
| Preliminary | principles, vocabulary, governance, evidence ceilings, authority |
| A — Architecture Vision | scope, stakeholders, measurable outcome, target state |
| B — Business Architecture | operating process, roles, capabilities, baseline/target business state |
| C — Information Systems Architectures | canonical data, applications, services, interfaces, views |
| D — Technology Architecture | runtimes, infrastructure, deployment and technology constraints |
| E — Opportunities & Solutions | reusable building blocks and solution composition |
| F — Migration Planning | sequenced transitions, work packages, 30/60/90 or equivalent |
| G — Implementation Governance | implementation evidence, conformance, courts, receipts |
| H — Architecture Change Management | verified outcomes modifying admitted architecture state |
| Requirements Management | continuous requirements, constraints, evidence, findings and gaps |

The lifecycle MUST remain compatible with iterative change. A phase label does not confer standing.

## 7. Baseline, target and gap

A conforming architecture episode MUST be able to identify:

```
Baseline → Gap → Transition → Target
```

A gap SHOULD be represented as machine-addressable unsatisfied obligations rather than prose only.

## 8. Architecture transitions

An architecture transition MUST bind:

- subject;
- baseline state;
- target state;
- applicable requirements;
- dependencies;
- work;
- evidence required for admission;
- authority required for consequence;
- verifier;
- resulting standing.

A candidate transition is not an admitted transition.

## 9. Views and viewpoints

A viewpoint declares a stakeholder concern and the projection rules required to answer it.

A view is:

```
View = π_viewpoint(O*)
```

Examples include:

- operator brief;
- executive board;
- system architecture;
- risk view;
- migration view;
- evidence view;
- daily architecture brief.

Views MUST NOT silently introduce facts absent from `O*`.

## 10. ASH Surface and human interaction

ASH Surface is the human projection layer for semantic architecture state.

A human surface SHOULD show:

- current standing;
- missing obligations;
- evidence;
- risks;
- decisions requiring authority;
- next lawful actions;
- provenance;
- deep links back to the exact semantic subject.

The surface SHOULD minimize human reconstruction.

## 11. Autonomic architecture brief

A STOGAF implementation MAY generate a daily or event-driven architecture brief from admitted state.

A brief SHOULD emphasize:

- what changed;
- what is blocked;
- what requires human judgment;
- what was automatically constructed;
- what remains UNKNOWN;
- which decisions could change standing.

The brief is a view, not a source of truth.

## 12. Deep-link context envelopes

A generated interaction SHOULD preserve enough semantic identity to reconstruct its subject.

A context envelope SHOULD include:

- canonical subject identity;
- architecture-state identity;
- viewpoint;
- evidence references;
- standing;
- authority ceiling;
- work identity when applicable;
- replay identity when applicable.

## 13. Semantic Jira

Semantic Jira (sJira) is the work projection of admitted architecture state.

Core rule:

> The graph is law; tickets are projections.

A semantic work order SHOULD bind:

- subject;
- obligation;
- owner;
- preconditions;
- required evidence;
- authority;
- verifier;
- dependencies;
- standing;
- receipt.

Editing a projection MUST NOT silently create architecture truth outside the canonical graph.

## 14. Semantic A2A

SA2A is the typed capability-interaction plane.

SA2A MUST distinguish:

- capability;
- computation;
- candidate output;
- evidence;
- authority;
- consequence.

An agent or model MAY OBSERVE, SELECT or CONSTRUCT within an admitted capability contract. It MUST NOT acquire DO authority merely by producing a candidate or plan.

## 15. BRCE governance

STOGAF adopts the BRCE separation:

```
SELECT ≠ CONSTRUCT ≠ DO
```

Consequential actuation MUST be bounded by explicit authority and receipt semantics.

Zero unreceipted actuation is the target invariant.

## 16. Provenance and standing

Architecture evidence MUST be capable of distinguishing:

- observed fact;
- derived fact;
- candidate;
- finding;
- verified result;
- authorized disposition.

Recommended standing vocabulary includes:

- UNKNOWN
- PARTIAL_ALIVE
- ALIVE
- BLOCKED
- REFUSED
- KNOWN_REPLAY

Standing MUST remain bounded to the exact subject, evidence and execution that established it.

## 17. MachineExperience

MachineExperience is admitted reusable organizational prior art.

It requires:

```
verified consequence
+ provenance
+ applicability
+ evidence ceiling
+ replay identity
```

MachineExperience MUST NOT broaden itself beyond the population and conditions established by evidence.

Contradictory evidence MUST be capable of narrowing, superseding, or invalidating prior experience.

## 18. Observability

Architecture observability SHOULD include:

- requirements satisfied / unsatisfied;
- gaps;
- work state;
- evidence completeness;
- authority transitions;
- verification;
- replay;
- architecture drift;
- view freshness;
- MachineExperience reuse.

OCEL is the preferred event backbone where object-centric process evidence is required.

## 19. Conformance ladder

Conformance is cumulative unless an implementation explicitly reports a non-cumulative experimental profile.

| Level | Name | Minimum capability |
|---|---|---|
| ST-0 | DOCUMENTED | architecture concepts exist in durable artifacts |
| ST-1 | ADDRESSABLE | canonical subjects have stable machine identities |
| ST-2 | LINKED | architecture subjects and dependencies are semantically linked |
| ST-3 | PROVENANCED | claims and transitions retain evidence provenance |
| ST-4 | CONSTRAINED | executable constraints and authority ceilings are enforced |
| ST-5 | GENERATED | architecture views/work/code are deterministically manufactured from admitted state |
| ST-6 | AUTONOMIC | admitted events can select and construct bounded architecture/work transitions without human reconstruction |
| ST-7 | ACTUATED | authorized consequence is executed and receipted |
| ST-8 | CLOSED LOOP | observed consequence reconciles back into architecture state |
| ST-9 | LEARNING | verified experience changes future architecture/work with replayable standing |

A system MUST NOT claim a higher cumulative level while a prerequisite level is unproven.

## 20. Repository model

A repository implementing STOGAF SHOULD make the following inspectable:

```
ontology / canonical graph
constraints
architecture episodes
work projections
capability contracts
views
verification courts
receipts
MachineExperience
conformance report
```

Generated projections SHOULD identify their producer and source semantic subject.

## 21. Failure and refusal semantics

A conforming implementation MUST fail closed when:

- required evidence is missing;
- authority is absent;
- subject identity is ambiguous;
- provenance is invalid;
- replay binding is broken;
- a transition exceeds its evidence ceiling.

Refusal is a valid architecture outcome.

## 22. Adoption

An enterprise MAY adopt STOGAF incrementally.

A recommended progression is:

```
documents
→ stable identities
→ semantic links
→ provenance
→ constraints
→ deterministic projections
→ autonomic construction
→ bounded actuation
→ consequence reconciliation
→ organizational learning
```

## 23. WD Case Study 2 reference episode

Western Digital Case Study 2 is the first reference architecture episode.

The baseline is fragmented failure-analysis evidence across unstructured and structured systems.

The target is a governed semantic failure-analysis operating loop.

Representative subject chain:

```
Drive
→ BOM
→ Component
→ Supplier
→ Lot
→ Process
→ Station
→ Observation
→ Evidence
→ FailureMode
→ HistoricalCase
→ DiagnosticWork
→ EngineerDisposition
→ VerificationReceipt
→ MachineExperience
```

The architecture loop is:

```
STANDARD
→ OBSERVE
→ ADMIT
→ WORK
→ ENGINEER DISPOSITION
→ VERIFY
→ MACHINE EXPERIENCE
→ STANDARD
```

The WD demo deliberately retains:

```
authority = SELECT_CONSTRUCT_ONLY
human_gate = ENGINEER_DISPOSITION_REQUIRED
evidence_ceiling = REPO_LOCAL_FIXTURE
```

Therefore the current cumulative conformance ceiling is **ST-4 CONSTRAINED**.

The Friday target is **ST-6 AUTONOMIC** at repository-local standing: the canonical graph must be sufficient to generate the work/view/application projections and execute their verification courts without a human reconstructing architecture context.

ST-7 and above remain unclaimed until consequential authority, consequence observation and production learning are actually evidenced.

## 24. Open questions

- Which portions of the profile should become public reusable ontology terms versus implementation-specific profile terms?
- Which architecture transitions require independent verification by policy?
- How should enterprise architecture conformance compose across repository boundaries?
- Which generated views require freshness receipts?
- What constitutes sufficient evidence to promote MachineExperience between populations?

## 25. Summary

STOGAF preserves enterprise architecture concerns while changing the execution model:

```
architecture document
    ↓
canonical semantic state
    ↓
constrained projection
    ↓
semantic work
    ↓
bounded capability interaction
    ↓
verified consequence
    ↓
reconciled architecture state
    ↓
reusable experience
```

The architecture exists once in admitted state and is projected many times.


## 26. v26.9.24 closure

This specification is complete for the v26.9.24 semantic release boundary.

The WD Case Study 2 reference episode remains bounded by its observed evidence: repository-local fixture standing, `SELECT_CONSTRUCT_ONLY` authority, and `ENGINEER_DISPOSITION_REQUIRED` for consequential decisions. ST-7 ACTUATED and higher are not implied by specification closure.

The implementation falsifier remains executable: malformed RDF, failed SHACL/SPARQL admission, broken generated projections, missing exact-source bindings, or an attempt to bypass the human authority gate prevents promotion.
