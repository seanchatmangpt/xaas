# ADR-004 — Use OCEL 2.0 for object-centric process evidence

**Status:** Accepted

## Context

Western Digital Case Study 2 requires a trustworthy failure-analysis system that joins fragmented evidence, distinguishes known from novel, recommends next work and retains a human loop.

## Decision

Represent events across cases, drives, lots, suppliers, firmware, stations and evidence objects.

## Rationale

FA processes are multi-object; case-centric logs lose relevant relationships.

## Consequences

- The decision is visible in the canonical STOGAF architecture episode.
- Any implementation/view that contradicts this ADR must be treated as architecture drift.
- Production claims remain bounded by the repository evidence ceiling.
