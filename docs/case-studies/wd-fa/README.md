# WD Case Study 2 — Semantic Failure Analysis

This directory is the decision-ready architecture package for Western Digital Case Study 2.

## Submission entrypoint

For the September 25 written response requested by WD, start with:

- `19-SEPTEMBER-25-SUBMISSION.md`

That document is the self-contained 5–8 page-equivalent proposal mapped to WD's requested sections. The remaining files are supporting architecture, implementation, evaluation and evidence artifacts.

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

1. `19-SEPTEMBER-25-SUBMISSION.md`
2. `00-WORKING-BACKWARDS.md`
3. `01-REQUIREMENTS-TRACEABILITY.md`
4. `02-BASELINE-TARGET-GAP.md`
5. `03-BUSINESS-ARCHITECTURE.md`
6. `04-DATA-ARCHITECTURE.md`
7. `05-APPLICATION-ARCHITECTURE.md`
8. `06-TECHNOLOGY-ARCHITECTURE.md`
9. `07-SECURITY-GOVERNANCE.md`
10. `08-EVALUATION-MEASUREMENT.md`
11. `09-MIGRATION-30-60-90.md`
12. `10-RISK-REGISTER.md`
13. `11-ARCHITECTURE-DECISIONS.md`
14. `12-DEMO-SCRIPT.md`
15. `13-C4-MERMAID.md`
16. `14-MACHINE-EXPERIENCE.md`
17. `15-SJIRA-SA2A.md`
18. `16-DFCM-CROSS-PRODUCT.md`
19. `17-FRIDAY-DEFINITION-OF-DONE.md`
20. `18-NON-CLAIMS.md`

Machine-readable projections live beside these documents:
`architecture-episode.json`, `requirements.json`, `conformance.json`, `viewpoints.json`, and `adm.json`.
