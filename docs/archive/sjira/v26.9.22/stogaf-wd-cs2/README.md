# Semantic Jira — v26.9.22 STOGAF / WD CS2

This directory is the machine-selectable work graph for closing WD Case Study 2 from current `ST-4 CONSTRAINED` to target `ST-6 AUTONOMIC` at repository-local standing.

The graph is law; these work-order files are projections.

## Selection rule

Choose the lowest-numbered non-ALIVE order whose dependencies are ALIVE or have exact sealed evidence.

## Authority

All orders are repository-local SELECT/CONSTRUCT work unless an order explicitly states otherwise. No order grants production FA disposition, merge, publish, deploy, delete, spend or external customer authority.

## ST-6 closure chain

```
SJ-011 STOGAF backfill
→ SJ-012 requirement graph
→ SJ-013 semantic constraints
→ SJ-014 viewpoint manufacture
→ SJ-015 sJira projection
→ SJ-016 SA2A capability selection
→ SJ-017 generated-runtime parity
→ SJ-018 receipt/replay closure
→ SJ-019 presentation parity
→ SJ-020 handoff/readiness
```

The chain is deliberately compositional. A failure in an upstream semantic obligation blocks downstream promotion.
