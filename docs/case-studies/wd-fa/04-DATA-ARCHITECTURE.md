# Data Architecture

## Canonical subject graph

```
FailureCase
├── Drive
│   ├── Serial
│   ├── Lot
│   ├── Supplier
│   ├── BOMRevision
│   ├── FirmwareRevision
│   └── TestStation
├── EvidenceArtifact
│   ├── report
│   ├── plot
│   ├── waveform
│   ├── image
│   └── structured test record
├── CandidateHypothesis
├── FailureMode
├── PriorCase
├── WorkOrder
├── EngineerDisposition
├── VerificationReceipt
└── MachineExperience
```

## Data contracts

Every evidence artifact SHOULD carry:

- evidence identity;
- source locator;
- modality;
- digest;
- observed/derived status;
- acquisition timestamp or version where available;
- source ACL/classification;
- subject relation;
- provenance chain.

## OCEL

OCEL 2.0 is used for object-centric event evidence because a single failure-analysis event can affect multiple persistent objects.

Representative events:

```
failure_observed
evidence_attached
triage_constructed
diagnostic_requested
diagnostic_observed
disposition_recorded
verification_observed
experience_admitted
standard_updated
```

## Structured/unstructured join rule

Joins SHOULD resolve through stable semantic identities and provenance rather than embedding similarity alone.

Text-to-SQL MAY be used for bounded structured retrieval. It MUST NOT become the sole semantic contract because the same subject spans files, images, object relations, provenance and work state.

## Multimodal rule

Normalization MUST NOT destroy the original artifact. Derived text/embedding/image features are projections with provenance back to the source.
