# P4 Claude Routine Deletion — the c4 crown falsifier (Remove(ClaudeCode) ⇒ Behavior unchanged)

## Summary

The binding architecture's central falsifier: when the hourly Claude cloud
routine (trigger `trig_01X4MaMBcr9DuFhVVZjJuLbQ`) is deleted, the identical
engineering loop must continue from durable XaaS state. Per DESIGN.md P4:
with the routine producing ZERO new cycles, the ledgered admission worker +
dispatcher complete ≥3 epochs / 24h end-to-end. Deleting the routine is the
operator's cut — and the last act of this milestone's autonomy arc.

## Status

BLOCKED — on `p3-unattended-epoch-zcode.md` (and the episode chain beneath
it).

## Scope

1. Precondition evidence: P3 standing ALIVE (unattended provider epoch).
2. Build the dispatch leg if missing: the zcode-side worker cadence (the
   installed plugin's xaas-worker agent/skill, or a scheduled headless
   `zcode --prompt` claim loop) that keeps epochs claimed without any human
   or Claude-routine session — ledgered as the standing wave coordinator's
   successor for ultracode work.
3. Operator pauses (not yet deletes) the routine; observe ≥24h: ≥3 epochs
   complete, receipts land, PROGRESS.md continuity maintained by the loop's
   own ledger writes.
4. Operator deletes the routine; observe one further cycle. Classify per the
   c4 doc: scheduling/continuity crossed DESIGN → ALIVE when behavior is
   unchanged.
5. Guard: missed-epoch detection is by then an ordinary domain invariant
   (AshOban-owned), not bootstrap safety.

## Key Invariant(s)

- The routine is deleted only after ≥3-epochs/24h evidence with it idle —
  never before (deleting early converts safety into an experiment).
- 並 laws apply to any standing zcode worker cadence (≤16 heavyweight
  in-flight, top-up only, [1302] storm protocol).

## Relationship to Existing Work

- `docs/ultracode/c4-architecture.md` (the falsifier, binding);
  `wave1-03-bootstrap.md` (the routine's reconstructed contract — the
  checklist this loop must have absorbed); `DESIGN.md` P4.

## Falsifiers / What Would Defeat This

- Any cycle post-deletion requires a human/Claude hand (continuity lie).
- Epoch count sustained only by re-litigating admission by hand (the
  Run-admission gap must be closed by the ledgered worker, not bridged).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | xaas @ 6ff1a32; routine external (claude.ai trigger) | absorbed so far: epoch advancement, gap selection (partially — receipts feature landing); NOT absorbed: autonomous Run admission | P3 → dispatch leg → 24h idle-routine evidence → operator deletes |
