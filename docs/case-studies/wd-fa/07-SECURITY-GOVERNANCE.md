# Security and Governance

## Boundary

The Friday demo is advisory/constructive only:

```
authority = SELECT_CONSTRUCT_ONLY
human_gate = ENGINEER_DISPOSITION_REQUIRED
```

## Required invariants

1. Candidate ranking does not grant authority.
2. Retrieval does not grant evidence admission.
3. A plan does not grant DO.
4. Missing authorization fails closed.
5. Source ACL/classification SHOULD be conserved into derived evidence.
6. Receipts bind exact subject, evidence, policy/version and verifier.
7. Private evidence SHOULD remain partitioned from unauthorized views.
8. No production write or external consequence is claimed by the demo.

## BRCE

```
Proposal
→ Admission
→ Authority
→ DO
→ Receipt
→ Replay
```

The Friday demo stops before production DO.

## Threats

| Threat | Control |
|---|---|
| confident false-known | deterministic applicability + falsifiers |
| prompt injection in source docs | source treated as evidence, never authority |
| stale evidence | version/freshness metadata |
| ACL leakage | authorization before projection |
| self-certification | independent verifier identity |
| replay mismatch | digest/exact-subject binding |
| model drift | candidate model is non-authoritative |
| architecture drift | generated/view parity courts |
