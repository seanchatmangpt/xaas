# OCEL Learning Episode

The WD reference now materializes the entire repository-local learning sequence in the real Ash-backed OCEL persistence layer:

```
failure_observed
→ triage_constructed
→ diagnostic_work_constructed
→ engineer_disposition_observed
→ verification_receipt_observed
→ machine_experience_admitted
→ standard_updated
```

Persistent objects include:

```
FailureCase
Drive
StandardWork
SemanticWorkOrder
EngineerDisposition
VerificationReceipt
MachineExperience
```

The episode is intentionally a fixture. The "engineer disposition observed" event records the repository-local verified fixture used to exercise the mechanics; it does not assert that a WD engineer made that decision.
