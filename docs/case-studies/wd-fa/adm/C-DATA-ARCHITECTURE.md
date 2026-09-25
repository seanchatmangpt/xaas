# Phase C — Data Architecture

## Canonical identities

Drive, FailureCase, Lot, Supplier, BOMRevision, FirmwareRevision, TestStation, EvidenceArtifact, FailureMode, WorkOrder, Disposition, VerificationReceipt and MachineExperience are modeled as addressable subjects.

## Event model

OCEL retains events with relationships to all affected objects instead of forcing one case-id-centric event stream.

## Provenance model

Every derived statement must be traceable to source evidence and transformation.

## Information lifecycle

```
source artifact
→ normalized evidence projection
→ semantic relation
→ candidate use
→ admission
→ disposition evidence
→ receipt
→ replay
```

Original sources remain authoritative for their observed content; normalized projections never replace them.
