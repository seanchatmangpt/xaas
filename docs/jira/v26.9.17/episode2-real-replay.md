# Episode₂ Real Replay — KNOWN → Replay with frontier_clean preserved (k1–k11 for real)

## Summary

The Episode₂ machinery is ALIVE (typed equivalence, replay route, structural
no-explore-unknown — 47 tests), but the real episode has never run. Per the
HDDL, Episode₂ must: reconstruct its world, PROVE semantic equivalence to
Episode₁, route through the admitted Machine Experience, replay the known
transition, and close with its own receipts/verification/affidavit — with
`frontier_clean` preserved through completion (the crown falsifier: if any
`explore-unknown` were needed, no valid crown plan exists).

## Status

BLOCKED — on `p2-lease-cycle-redispatch.md` (needs a real `experience-1`)
and materially on `frontier-clean-ocel-wiring.md`.

## Scope

1. After Episode₁ completes and its Machine Experience is admitted
   (`experience-admitted experience-1`, `replay-contract experience-1`),
   construct Episode₂'s record from the SAME subject/goal class.
2. Run the real chain: `prove_semantic_equivalence(e2, e1)` →
   `route_known_replay` → `replay_known_transition` → authority/DO path →
   receipts → independent verify → OCEL process observation → e2 affidavit.
3. Measure and record frontier use across the whole episode (allocator call
   count must be ZERO for e2; the wave-4 test harness already counts).
4. Update `RELEASE-STATE-v26.9.17.md` predicates: `equivalent`, `replayed`,
   `frontier-clean e2`, `episode-alive e2`, `affidavit-issued e2`.

## Key Invariant(s)

- Equivalence is proven structurally (goal/subject/steps/bounds), never by
  analogy; a non-equivalent subject must fail `equivalence_failed` and never
  reach replay.
- Replay ≠ DO: replayed transitions still cross the consequence fence where
  consequences exist.
- `frontier_clean(Episode₂)` must be WITNESSED (see the wiring ticket), not
  attested.

## Relationship to Existing Work

- `ep2-replay.md` (machinery); HDDL domain sections 6–7 (binding contract);
  `certify-prep.md` gate 10 (CHI-REPLAY, machinery-level);
  `affidavit-followup-binding.md` (e2 evidence binding).

## Falsifiers / What Would Defeat This

- Episode₂ completes but the allocator count > 0 (crown falsified — the
  "learned" residue was not actually learned; report, do not patch around).
- Equivalence check passes on a mismatched subject (analogy leak).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | autofde-lab feat/ep2-replay-contract @ 112d7e41 | machinery 47/0; episode NOT RUN | wait for e1 → run k1–k11 → predicate updates |
