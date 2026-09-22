# Business Architecture

## Outcome

Reduce repeated failure-analysis work while preserving engineer authority over consequential conclusions.

## Core roles

| Role | Responsibility | Authority |
|---|---|---|
| FA engineer | disposition, investigation judgment, interpretation of novel evidence | consequential FA disposition |
| FA manager | queue health, policy, escalation, staffing, adoption | operating governance |
| firmware analysis | firmware diagnostics and corrective work | bounded domain action |
| supplier quality | lot/supplier investigation and corrective work | bounded domain action |
| data/platform team | source integration, lineage, service reliability | platform operation |
| security/governance | access, purpose, audit, retention | policy/authorization |
| semantic system | observe, retrieve, rank, admit, construct work, prepare receipts | SELECT/CONSTRUCT only in pilot |

## Value stream

```
Symptom observed
→ reconstruct subject
→ retrieve evidence and prior art
→ rank hypotheses
→ admit KNOWN/PARTIAL/UNKNOWN
→ construct diagnostic work
→ engineer disposition
→ verify consequence
→ capture reusable experience
```

## Scarce-resource model

The system optimizes scarce human decision attention.

Desired direction:

```
HumanImplementationTransitions / TotalEngineeringTransitions → 0
LLMCallsOnKnownClasses / KnownClassExecutions → 0
VerifiedPriorArtReuse / EligibleCases → 1
```

These are architectural target directions, not current WD measurements.

## Operating principle

Known work should become standard work. Novel work should create new reusable standard work only after verified disposition.
