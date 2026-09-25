# ADR-007 — Manufacture alternate runtime projections

**Status:** Accepted

## Context

Western Digital Case Study 2 requires a trustworthy failure-analysis system that joins fragmented evidence, distinguishes known from novel, recommends next work and retains a human loop.

## Decision

FastAPI/Next.js should be generated from admitted semantics rather than maintained as independent WD application source.

## Rationale

The crossover experiment requires semantic portability, not framework duplication.

## Consequences

- The decision is visible in the canonical STOGAF architecture episode.
- Any implementation/view that contradicts this ADR must be treated as architecture drift.
- Production claims remain bounded by the repository evidence ceiling.
