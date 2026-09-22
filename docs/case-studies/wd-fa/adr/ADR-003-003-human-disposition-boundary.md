# ADR-003 — Preserve engineer disposition authority for the Friday pilot

**Status:** Accepted

## Context

Western Digital Case Study 2 requires a trustworthy failure-analysis system that joins fragmented evidence, distinguishes known from novel, recommends next work and retains a human loop.

## Decision

Friday surfaces stop at SELECT/CONSTRUCT and require ENGINEER_DISPOSITION_REQUIRED for consequential FA disposition.

## Rationale

No production authority policy is evidenced by the repository-local case.

## Consequences

- The decision is visible in the canonical STOGAF architecture episode.
- Any implementation/view that contradicts this ADR must be treated as architecture drift.
- Production claims remain bounded by the repository evidence ceiling.
