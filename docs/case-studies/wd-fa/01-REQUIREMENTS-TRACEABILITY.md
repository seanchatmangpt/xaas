# Requirements Traceability

Each requirement is bound to an architecture element, implementation surface, falsifier, court and evidence ceiling.

| ID | WD requirement | STOGAF obligation | Implementation | Falsifier / court | Friday standing target |
|---|---|---|---|---|---|
| R-01 | Ranked probable failure modes | candidate ranking is separate from admission | `WdFa.presentation_state/2`, hypotheses | high-scoring novel candidate MUST remain UNKNOWN | ALIVE repo-local |
| R-02 | Supporting evidence | every recommendation binds evidence identities | OCEL objects + evidence list | recommendation with no supporting evidence is refused/partial | ALIVE repo-local |
| R-03 | Closest prior FA cases | prior art is explicit and applicability-bounded | `prior_cases` | nearest case cannot create KNOWN | ALIVE repo-local |
| R-04 | Specific next action | work is typed and owned | `next_action`, `owning_team`, sJira | action must exist for every surfaced case | ALIVE repo-local |
| R-05 | Messy corpus incl. images/plots | preserve modality/source provenance | structured + narrative + SVG plot ingestion fixture | source-less normalization is non-conformant | ALIVE representative fixture; production connectors UNKNOWN |
| R-06 | Structured joins | serial/lot/supplier/BOM/FW/station are object relations | OCEL object graph | flat text-only join is insufficient | ALIVE fixture |
| R-07 | Grounding / traceability | every claim retains source and standing | OCEL + receipts + STOGAF | unsupported claim cannot be promoted | ALIVE fixture |
| R-08 | Avoid confidently wrong root cause | probability cannot grant admission | deterministic evidence closure | false-known negative control | ALIVE fixture |
| R-09 | Visible confidence | expose confidence basis, not only scalar score | `confidence_basis` | UI hides basis | ALIVE |
| R-10 | Human loop | consequential disposition remains bounded | ENGINEER_DISPOSITION_REQUIRED | ambient DO is a failure | ALIVE |
| R-11 | Known vs novel | KNOWN/PARTIAL/UNKNOWN are first-class | deterministic kernel | novel nearest-neighbor becomes KNOWN | ALIVE |
| R-12 | Feedback loop | verified disposition may become MachineExperience | novel replay | unverified candidate becomes experience | ALIVE fixture |
| R-13 | Measurement incl. MTTR | distinguish offline, shadow and production metrics | evaluation plan | invented production improvement | DESIGN |
| R-14 | Security/governance | ACL/provenance/authority conserved | STOGAF + BRCE | unauthorized evidence/DO | DESIGN/PARTIAL |
| R-15 | Evaluation rigor | positive, partial, novel, tamper and replay courts | Chicago + Playwright | only happy-path tests | ALIVE fixture |
| R-16 | 30/60/90 | progressive evidence and authority expansion | migration plan | claims outrun measured evidence | DESIGN |
| R-17 | Architecture tradeoffs | explicit choices and non-choices | ADR log | hidden framework assumptions | ALIVE docs |
| R-18 | Pragmatic FDE delivery | build smallest useful vertical slice first | XaaS demo + generated target | architecture without executable slice | ALIVE repo-local |

## Traceability chain

Every Friday claim SHOULD be answerable as:

```
WD requirement
→ STOGAF requirement
→ architecture building block
→ source/ontology
→ executable implementation
→ falsifier
→ exact-head court
→ receipt
→ evidence ceiling
→ presentation view
```

Any missing link remains PARTIAL_ALIVE or UNKNOWN rather than being verbally filled during the presentation.
