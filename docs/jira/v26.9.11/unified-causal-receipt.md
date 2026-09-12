# Unified Causal Receipt — extend the meta-receipt to bind the full causal episode identity

## Summary

Extend the existing meta-receipt (`Merkle(Σ, μ, H, substrate, R_prev)`) into a full
`ProcessReceipt` that binds the complete causal episode identity — from raw
observation through admitted knowledge, planning, decision, actuation, and
consequence — into a single chained, verifiable receipt.

## Status

Candidate / Not Yet Implemented

## Scope

Required components (verbatim from the vetted workstream description):

- Canonical receipt schema
- Deterministic episode identity
- Merkle chaining
- Receipt signer
- Receipt verifier
- Lineage traversal
- Consequence binding
- Authority binding
- Planning/causal/stability provenance
- Replay descriptor
- Receipt diffing
- Incomplete-receipt refusal

The `ProcessReceipt` binds the following fields: `episode_id`, `observation_ids`,
`admitted_observation_hash`, `ontology_hash`, `semantic_projection_hash`,
`causal_admission_hash`, `planning_problem_hash`, `planner_identity`,
`policy_hash`, `coupling_result_hash`, `authority_receipt`,
`actuation_identity`, `consequence_identity`, `valid_time`, `observation_time`,
`stability_result`, `generator_identity`, `runtime_identity`,
`predecessor_receipt`, `replay_descriptor`.

## Key Invariant(s)

Existing meta-receipt (baseline, already in place):

```
R = Merkle(Σ, μ, H, substrate, R_prev)
```

Target causal-identity chain to be established by this workstream:

```
ID(O) leads-to ID(K) leads-to ID(P) leads-to ID(Intent) leads-to ID(DO) leads-to ID(Consequence) leads-to ID(R)
```

Where each `leads-to` edge must be reconstructable via lineage traversal and
verifiable against the corresponding hash/identity field in the
`ProcessReceipt` (e.g. `ID(O)` against `observation_ids` /
`admitted_observation_hash`, `ID(K)` against `ontology_hash` /
`semantic_projection_hash` / `causal_admission_hash`, `ID(P)` against
`planning_problem_hash` / `planner_identity`, `ID(Intent)` against
`policy_hash` / `coupling_result_hash` / `authority_receipt`, `ID(DO)` against
`actuation_identity`, `ID(Consequence)` against `consequence_identity` /
`stability_result`, `ID(R)` against `predecessor_receipt` and the resulting
chained receipt hash itself).

## Relationship to Existing Work

This extends, rather than replaces, the existing meta-receipt
(`Merkle(Σ, μ, H, substrate, R_prev)`) already present in the repo's receipt
chaining model. The `predecessor_receipt` field preserves the existing
`R_prev` chaining semantics; this workstream is additive at the schema level
(more bound identities per receipt), not a redesign of the chaining mechanism
itself.

## Falsifiers / What Would Defeat This

- A `ProcessReceipt` is produced that verifies successfully (passes the
  receipt verifier) while one or more of its bound identities
  (`observation_ids`, `causal_admission_hash`, `planner_identity`,
  `actuation_identity`, `consequence_identity`, etc.) does not correspond to
  the actual episode data it claims to represent — i.e. the verifier accepts
  a receipt whose lineage does not actually reconstruct via lineage
  traversal.
- A receipt with a missing or malformed required field (per the canonical
  receipt schema) is accepted by the receipt signer/verifier instead of being
  refused by incomplete-receipt refusal.
- Two receipts for genuinely different episodes produce the same
  `episode_id` (deterministic episode identity is not actually deterministic
  or not actually unique per episode), breaking Merkle chaining integrity.
- Receipt diffing fails to detect a real, deliberate divergence between two
  receipts that share a `predecessor_receipt` but differ in
  `consequence_identity` or `stability_result` — i.e. the diff tool reports
  "no material difference" for receipts that in fact bind different
  consequences.
