# Temporal Process Memory — bitemporal (valid-time / observation-time) state reconstruction

## Summary

Store both valid time (`t_v`, when something was true in the world) and
observation/transaction time (`t_o`, when the system learned it), so decision
replay only uses what was knowable at decision time — never information
discovered later.

## Status

Candidate / Not Yet Implemented

## Scope

- bitemporal event model
- valid-time interval representation
- observation/transaction-time representation
- historical state reconstruction
- historical observation projection
- retroactive observation handling
- correction/supersession semantics
- temporal query API
- temporal replay verifier
- temporal receipt hashing

## Key Invariant(s)

`Replay(d_t, O_<=t) = d_t` under identical admitted identities and
deterministic machinery.

## Relationship to Existing Work

Not specified in the vetted source material for this ticket.

## Falsifiers / What Would Defeat This

- Replay of a past decision `d_t` produces a different result when re-run
  against `O_<=t` (the observation set knowable at time `t`) under identical
  admitted identities and deterministic machinery — a direct violation of the
  `Replay(d_t, O_<=t) = d_t` invariant.
- A retroactive observation (one learned at `t_o > t` but valid at `t_v <= t`)
  leaks into a reconstruction or replay bounded at `t`, i.e. historical state
  reconstruction or historical observation projection surfaces information
  that was not yet knowable at the query time.
- A correction/supersession of a prior observation silently overwrites the
  original record rather than being represented as a new bitemporal event,
  making it impossible to reconstruct what was believed before the
  correction.
- The temporal query API returns results that conflate valid-time and
  observation-time axes (e.g. cannot answer "what did we know at `t_o`" and
  "what was true at `t_v`" as independent questions), or the temporal receipt
  hashing fails to detect a mutation to either time axis.
