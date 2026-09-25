# Frontier-Clean OCEL Wiring — witness-derived frontier predicate + real step projection

## Summary

Episode₂'s honest gaps (from `ep2-replay.md` §4): (1) `frontier_clean` is
CALLER-DECLARED at route time — nothing derives it from process evidence;
(2) `EpisodeRecord` steps are declared, not projected from a real episode's
OCEL trace. Both must become witness-derived or the crown property
(`frontier_clean(Episode₂)` through completion) stays self-attested.

## Status

Queued / Not Started (agent work, autofde-lab; ideally the P2 episode's
subject).

## Scope

1. Derive `frontier_clean` from OCEL witnesses: an episode whose event trace
   contains zero frontier-allocator invocations (and whose CHI-KNOWN gate
   confirms known-routing) IS frontier_clean — compute it, never accept the
   caller's word. Wire the derived predicate into `route_known_replay`
   (replace/augment the declared flag).
2. Project `EpisodeRecord` steps from the real OCEL trace of the completed
   episode (step extraction: goal/subject/steps/bounds filled from events,
   not hand-declared).
3. Tests, both directions: a genuinely-clean trace routes; a trace with one
   frontier event refuses `REFUSED_FRONTIER_NOT_CLEAN` — and a forged
   "clean" attestation without a matching trace is refused.
4. Keep the structural absence of explore-unknown in the replay module
   (import-graph test stays).

## Key Invariant(s)

- Frontier accounting is measured from process evidence, not declared.
- The equivalence court stays pure/typed (no LLM-judgment channel opens as a
  side effect of trace projection).

## Relationship to Existing Work

- `ep2-replay.md` (the machinery + named gaps); `boundary-beam4pm.md` (the
  OCEL conformance court that grounds trace semantics); feeds
  `episode2-real-replay.md` and `p4-claude-routine-deletion.md`.

## Falsifiers / What Would Defeat This

- A trace-less caller still routes (predicate not actually derived).
- Projection fabricates steps for events that never happened (OCEL gaps
  become silent zeros).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | queued | autofde-lab feat/ep2-replay-contract @ 112d7e41 | 47 tests green (machinery); gaps named in §4 | derived predicate + step projection + bidirectional tests |
