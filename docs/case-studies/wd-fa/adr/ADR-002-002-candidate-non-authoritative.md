# ADR-002 — Keep candidate ranking non-authoritative

**Status:** Accepted

## Context

Western Digital Case Study 2 requires a trustworthy failure-analysis system that joins fragmented evidence, distinguishes known from novel, recommends next work and retains a human loop.

## Decision

Statistical/model ranking may order candidates; deterministic applicability, evidence completeness and falsifiers establish standing.

## Rationale

Similarity and probability are useful for prioritization but insufficient for engineering admission.

## Consequences

- The decision is visible in the canonical STOGAF architecture episode.
- Any implementation/view that contradicts this ADR must be treated as architecture drift.
- Production claims remain bounded by the repository evidence ceiling.
