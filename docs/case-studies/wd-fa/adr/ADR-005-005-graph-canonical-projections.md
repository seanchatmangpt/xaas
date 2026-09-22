# ADR-005 — Make the graph canonical and tickets/views projections

**Status:** Accepted

## Context

Western Digital Case Study 2 requires a trustworthy failure-analysis system that joins fragmented evidence, distinguishes known from novel, recommends next work and retains a human loop.

## Decision

sJira, browser views, decks and generated applications derive from O*.

## Rationale

This prevents drift and repeated human reconstruction of architecture context.

## Consequences

- The decision is visible in the canonical STOGAF architecture episode.
- Any implementation/view that contradicts this ADR must be treated as architecture drift.
- Production claims remain bounded by the repository evidence ceiling.
