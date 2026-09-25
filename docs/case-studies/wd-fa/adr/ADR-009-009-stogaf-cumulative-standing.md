# ADR-009 — Use cumulative STOGAF conformance with explicit ceilings

**Status:** Accepted

## Context

Western Digital Case Study 2 requires a trustworthy failure-analysis system that joins fragmented evidence, distinguishes known from novel, recommends next work and retains a human loop.

## Decision

Claim ST-4 currently, target ST-6 Friday, and leave ST-7+ UNKNOWN.

## Rationale

Architecture maturity must not outrun exact-head evidence.

## Consequences

- The decision is visible in the canonical STOGAF architecture episode.
- Any implementation/view that contradicts this ADR must be treated as architecture drift.
- Production claims remain bounded by the repository evidence ceiling.
