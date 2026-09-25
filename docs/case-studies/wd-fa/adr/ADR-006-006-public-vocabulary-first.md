# ADR-006 — Reuse public semantic vocabularies before local terms

**Status:** Accepted

## Context

Western Digital Case Study 2 requires a trustworthy failure-analysis system that joins fragmented evidence, distinguishes known from novel, recommends next work and retains a human loop.

## Decision

Use PROV-O, ORG, SKOS, SHACL and related standards where semantics fit.

## Rationale

This improves interoperability and minimizes private vocabulary.

## Consequences

- The decision is visible in the canonical STOGAF architecture episode.
- Any implementation/view that contradicts this ADR must be treated as architecture drift.
- Production claims remain bounded by the repository evidence ceiling.
