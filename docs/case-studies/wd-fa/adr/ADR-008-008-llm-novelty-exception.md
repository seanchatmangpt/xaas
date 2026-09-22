# ADR-008 — Treat general LLM reasoning as a novelty exception path

**Status:** Accepted

## Context

Western Digital Case Study 2 requires a trustworthy failure-analysis system that joins fragmented evidence, distinguishes known from novel, recommends next work and retains a human loop.

## Decision

KNOWN classes should execute through deterministic machinery; frontier reasoning is reserved for unresolved semantics.

## Rationale

Mechanized recurring work should reduce future intelligence demand.

## Consequences

- The decision is visible in the canonical STOGAF architecture episode.
- Any implementation/view that contradicts this ADR must be treated as architecture drift.
- Production claims remain bounded by the repository evidence ceiling.
