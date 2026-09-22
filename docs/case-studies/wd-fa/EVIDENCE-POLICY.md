# Evidence Authorization Policy

Repository fixtures now carry:

```
classification = INTERNAL_FIXTURE
purpose = FA_TRIAGE
source_ref = fixture://...
```

The policy court fails closed when:

- caller clearance does not include the source classification;
- requested purpose differs from the evidence purpose;
- a PRIVATE_FIXTURE is requested with only INTERNAL_FIXTURE clearance.

This proves policy mechanics at the repository fixture layer.

It does **not** prove integration with WD IAM, document ACLs, row-level security or production information partitions; R-14 therefore remains PARTIAL_ALIVE.
