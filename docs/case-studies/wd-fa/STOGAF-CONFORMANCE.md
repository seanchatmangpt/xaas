# WD Case Study 2 — STOGAF Conformance

**RFC:** Semantic TOGAF v26.9.22  
**Subject:** WD Case Study 2 failure-analysis quality loop  
**Evidence ceiling:** REPO_LOCAL_FIXTURE  
**Current cumulative level:** ST-4 CONSTRAINED  
**Friday target:** ST-6 AUTONOMIC  
**Authority:** SELECT_CONSTRUCT_ONLY  
**Human gate:** ENGINEER_DISPOSITION_REQUIRED

## Baseline

Failure-analysis evidence is fragmented across reports and structured provenance. Engineers repeatedly reconstruct the relationship between symptom, drive/build history, evidence, prior cases and next action.

## Target

A canonical semantic state supports deterministic projections for:

- engineer triage;
- work obligations;
- evidence and provenance;
- architecture views;
- executive views;
- generated application surfaces;
- MachineExperience replay.

## Gap

The remaining gap is not a new FA algorithm. It is closure across projections:

```
canonical O*
→ architecture view
→ sJira work
→ SA2A capability
→ Ash/XaaS runtime
→ generated runtime
→ Playwright / Chicago court
→ receipt
```

No projection may silently become a new source of truth.

## ADM episode

| Phase | WD CS2 interpretation | Current evidence |
|---|---|---|
| Preliminary | authority, evidence ceilings, ontology-first rule | SELECT_CONSTRUCT_ONLY; ENGINEER_DISPOSITION_REQUIRED |
| A | reduce repeated FA work without sacrificing trust | case-study value thesis |
| B | baseline / target FA operating process | STANDARD→OBSERVE→ADMIT→WORK→DISPOSITION→VERIFY→EXPERIENCE |
| C | evidence graph, work, APIs, human views | OCEL, Ash, LiveView, sJira |
| D | Ash/Postgres/OCEL and generated-stack target | XaaS reference runtime |
| E | reusable semantic building blocks | evidence, triage, receipt, MachineExperience, SA2A |
| F | staged rollout | 30/60/90 case-study plan |
| G | exact-head implementation governance | Chicago, Playwright, CI, no-mock court |
| H | verified experience changes future standard work | repo-local UNKNOWN→MachineExperience→KNOWN fixture |
| Requirements | continuous obligations and evidence | sJira projection |

## Architecture building blocks

1. **EvidenceGraph** — object-centric provenance across drive/build/evidence subjects.
2. **TriageAdmission** — deterministic KNOWN/PARTIAL/UNKNOWN admission.
3. **SemanticWorkOrder** — sJira projection of missing evidence and diagnostic work.
4. **EngineerDisposition** — consequential FA authority boundary.
5. **VerificationReceipt** — exact subject/evidence/verifier binding.
6. **MachineExperience** — admitted reusable prior art.
7. **MorningBriefView** — operator projection showing only what needs human judgment.
8. **GeneratedProjection** — alternate runtime/view manufactured from the same semantic state.

## Viewpoints

| Viewpoint | Projection | Primary concern |
|---|---|---|
| FA engineer | FA Morning Brief | What requires my judgment now? |
| FA manager | operating board | What is blocked, aging, recurring or missing evidence? |
| Executive | FA Agent Board Deck | What value, risk and adoption decision exists? |
| Architecture | System / Space | What is canonical, generated, bounded and reusable? |
| Hiring assessment | WD Case Study 2 Deck | Does the design answer the brief with evidence? |

## Conformance

| Level | Standing | Evidence / gap |
|---|---|---|
| ST-0 DOCUMENTED | ALIVE | RFC and WD conformance package |
| ST-1 ADDRESSABLE | ALIVE | stable OCEL/work identities |
| ST-2 LINKED | ALIVE | object/event and work relationships |
| ST-3 PROVENANCED | ALIVE | source-bound evidence and receipts |
| ST-4 CONSTRAINED | ALIVE | deterministic admission and authority ceiling |
| ST-5 GENERATED | PARTIAL_ALIVE | views exist; complete canonical graph→projection manufacture is under closure |
| ST-6 AUTONOMIC | PARTIAL_ALIVE | sJira/SA2A surfaces exist; WD event→work→verification closure remains under court |
| ST-7 ACTUATED | UNKNOWN | no consequential production DO is claimed |
| ST-8 CLOSED_LOOP | UNKNOWN | fixture learning exists; cumulative production closed-loop standing is not claimed |
| ST-9 LEARNING | UNKNOWN | production organizational-learning effect is unmeasured |

## Friday ST-6 acceptance

ST-6 is earned only if one admitted WD subject can drive, without human reconstruction:

1. deterministic architecture/work selection;
2. sJira obligation projection;
3. bounded SA2A capability selection;
4. Ash/XaaS reference behavior;
5. generated alternate runtime/view behavior;
6. Chicago and Playwright verification;
7. a replayable exact-head receipt.

This is repository-local standing only.

## Explicit non-claims

This conformance report does not claim:

- WD production data access;
- Toyota integration;
- production deployment;
- measured WD MTTR improvement;
- production actuation;
- external customer authority;
- ST-7, ST-8 or ST-9 cumulative standing.
