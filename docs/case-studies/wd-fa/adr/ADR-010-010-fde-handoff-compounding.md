# ADR-010 — Define FDE success as compounding capability plus handoff

**Status:** Accepted

## Context

Western Digital Case Study 2 requires a trustworthy failure-analysis system that joins fragmented evidence, distinguishes known from novel, recommends next work and retains a human loop.

## Decision

The engagement must leave reusable interfaces, semantics, courts, views, runbooks and ownership rather than permanent FDE dependency.

## Rationale

One-off delivery does not change the economics of subsequent enterprise work.

## Consequences

- The decision is visible in the canonical STOGAF architecture episode.
- Any implementation/view that contradicts this ADR must be treated as architecture drift.
- Production claims remain bounded by the repository evidence ceiling.
