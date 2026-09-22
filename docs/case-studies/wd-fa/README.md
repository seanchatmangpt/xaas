# WD Case Study 2 — Semantic Failure Analysis

This directory is the decision-ready architecture package for Western Digital Case Study 2.

The implementation is deliberately modeled as a **closed quality operating loop**, not a RAG chatbot:

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

## Canonical architecture rule

```
A = μ(O*)
```

- `O*` is admitted enterprise state.
- `μ` is lawful manufacture.
- `A` is a bounded artifact or projection.

The ontology/graph is canonical. Browser views, sJira work, SA2A capability calls, decks, APIs, receipts and generated runtimes are projections.

## Current evidence ceiling

```
STOGAF current: ST-4 CONSTRAINED
STOGAF target:  ST-6 AUTONOMIC
authority:      SELECT_CONSTRUCT_ONLY
human gate:     ENGINEER_DISPOSITION_REQUIRED
evidence:       REPO_LOCAL_FIXTURE
```

No file in this directory claims WD production data access, production deployment, measured production MTTR improvement, customer authority or production actuation.

## Reading order

1. `00-WORKING-BACKWARDS.md`
2. `01-REQUIREMENTS-TRACEABILITY.md`
3. `02-BASELINE-TARGET-GAP.md`
4. `03-BUSINESS-ARCHITECTURE.md`
5. `04-DATA-ARCHITECTURE.md`
6. `05-APPLICATION-ARCHITECTURE.md`
7. `06-TECHNOLOGY-ARCHITECTURE.md`
8. `07-SECURITY-GOVERNANCE.md`
9. `08-EVALUATION-MEASUREMENT.md`
10. `09-MIGRATION-30-60-90.md`
11. `10-RISK-REGISTER.md`
12. `11-ARCHITECTURE-DECISIONS.md`
13. `12-DEMO-SCRIPT.md`
14. `13-C4-MERMAID.md`
15. `14-MACHINE-EXPERIENCE.md`
16. `15-SJIRA-SA2A.md`
17. `16-DFCM-CROSS-PRODUCT.md`
18. `17-FRIDAY-DEFINITION-OF-DONE.md`
19. `18-NON-CLAIMS.md`

Machine-readable projections live beside these documents:
`architecture-episode.json`, `requirements.json`, `conformance.json`, `viewpoints.json`, and `adm.json`.
