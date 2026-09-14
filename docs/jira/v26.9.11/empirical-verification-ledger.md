# Empirical Verification Ledger — typed claim status, never collapse planned/implemented/executed/verified

## Summary

Formalize the distinction the Nov-2025 paper itself blurred (claiming production
convergence data while also stating production deployment had not occurred). Every
claim gets a typed status: `DECLARED | DERIVED | GENERATED | BUILT | EXECUTED |
OBSERVED | VERIFIED | REFUSED | BLOCKED | UNSUPPORTED`.

## Status

Candidate / Not Yet Implemented

## Scope

Required components:

- evidence ledger
- subject identity binding
- toolchain identity binding
- environment identity
- command receipt
- exit-code receipt
- test-result receipt
- benchmark receipt
- verification-ladder state
- exact-head identity
- stale-evidence detector
- reusable-evidence admission rule

## Key Invariant(s)

- Every claim MUST carry exactly one typed status from the fixed set:
  `DECLARED | DERIVED | GENERATED | BUILT | EXECUTED | OBSERVED | VERIFIED | REFUSED | BLOCKED | UNSUPPORTED`.
- Planned, implemented, executed, and verified are distinct states and MUST NOT be
  collapsed into one another — a claim that is `DECLARED` or `DERIVED` cannot be
  reported as `EXECUTED` or `VERIFIED` without the corresponding receipt.
- The motivating case this ticket formalizes against: a claim of production
  convergence data coexisting with an admission that production deployment had not
  occurred (Nov-2025 paper) — i.e. `OBSERVED`/`VERIFIED`-shaped language attached to
  a subject that was, at best, `DECLARED` or `DERIVED`.

## Relationship to Existing Work

Not specified in the vetted body content beyond the Nov-2025 paper reference above;
no other ticket/PR relationship is claimed here.

## Falsifiers / What Would Defeat This

- A claim is reported as `VERIFIED` or `OBSERVED` without an accompanying command
  receipt, exit-code receipt, or test/benchmark receipt binding it to a specific
  subject and toolchain identity.
- The stale-evidence detector fails to flag a receipt whose subject identity,
  toolchain identity, or exact-head identity no longer matches current state (i.e.
  an old receipt is silently treated as still valid).
- The reusable-evidence admission rule allows a receipt to be reused across a
  different subject, toolchain, or environment identity than the one it was
  produced under.
- Two conflicting status claims about the same subject (e.g. "deployed to
  production" and "not yet deployed to production") are both present in the ledger
  without one being resolved to the correct typed status — i.e. the ledger
  reproduces rather than prevents the original blurring.
