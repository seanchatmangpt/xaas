# ADR-001 — Model failure analysis as a quality operating loop, not a chatbot

**Status:** Accepted

## Context

Western Digital Case Study 2 requires a trustworthy failure-analysis system that joins fragmented evidence, distinguishes known from novel, recommends next work and retains a human loop.

## Decision

Use STANDARD→OBSERVE→ADMIT→WORK→DISPOSITION→VERIFY→EXPERIENCE→STANDARD as the governing process.

## Rationale

Chat-first architecture does not capture authority, work, verification or organizational learning.

## Consequences

- The decision is visible in the canonical STOGAF architecture episode.
- Any implementation/view that contradicts this ADR must be treated as architecture drift.
- Production claims remain bounded by the repository evidence ceiling.
