# Object-Centric Event Projection — replace case-oriented workflow execution with OCEL-shaped events

## Summary

Support events that relate to multiple objects/object-types ({o_1,...,o_n})
instead of forcing a single artificial case identifier. Replaces
case-oriented workflow execution with an OCEL-shaped (Object-Centric Event
Log) event model in `~/xaas`.

## Status

Candidate / Not Yet Implemented

## Scope

Required components:

- typed event entity
- typed object entity
- event-object relation
- object-object relation
- object state delta
- OCEL projection
- OCEL import
- Ash-resource identity mapping
- case-view derivation (not canonical case storage)

## Key Invariant(s)

- An event relates to a set of objects, not a single case: `event → {o_1, ..., o_n}`
- Case views are derived, not stored: `case_view = projection(events, objects)`,
  never a canonical persisted case record.

## Relationship to Existing Work

No relationship to other tickets/PRs was provided in the source material for
this ticket; none is asserted here.

## Falsifiers / What Would Defeat This

- An event is found that cannot be modeled as relating to a set of typed
  objects (i.e. requires a single artificial case identifier to represent
  correctly).
- A canonical case record is required to persist for correctness (rather than
  being derivable on demand from events + objects), which would violate the
  case-view-derivation invariant.
- The Ash-resource identity mapping cannot represent an existing Ash resource's
  identity without loss, blocking OCEL import/projection round-tripping.
- Object-object relations or object state deltas cannot be represented without
  reintroducing a case-oriented join table.
