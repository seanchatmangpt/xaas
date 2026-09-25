# Release Certification Final — `release-qualified v26-9-17` SATISFIED (t5 close-out)

## Summary

The m-certify-release precondition set, restated from the HDDL: verified ∧
process-conformant ∧ affidavit-issued for BOTH episodes; experience-1
admitted with replay-contract; e2 equivalent + replayed + frontier-clean;
the release tag cut. When every feeding ticket closes, this ticket flips the
authoritative predicate table and cuts the release record.

## Status

BLOCKED — on all Phase 0–4 tickets; this is the milestone terminator.

## Scope

1. Precondition audit against `RELEASE-STATE-v26.9.17.md` (durable copy in
   `docs/ultracode/wave-v26.9.17-receipts/`): every NOT-SATISFIED/PARTIAL/
   CLAIMED-UNVERIFIED/UNKNOWN row either flipped SATISFIED with witnessed
   evidence, or explicitly waived by the operator with the reason recorded
   (no silent skips — disagreement register D1–D8 must each be resolved or
   carried knowingly).
2. Re-run the crown runner from the final integrated tip (post
   `ep2-certify-integration.md`): exit 0, 12/12.
3. Update the predicate table + counts; write the release record (tag SHA,
   integrated tip, affidavit artifact hashes, the resolved operator-act log).
4. Commit the updated RELEASE-STATE + release record; operator decides PR.

## Key Invariant(s)

- Certification is adjudicated from witnessed receipts only — a predicate
  flips on evidence, never on plan.
- CLAIMED-UNVERIFIED entries cannot certify (executor claims without
  observer confirmation stay unconfirmed).

## Relationship to Existing Work

- Everything: this ticket's scope IS the milestone's dependency terminal.
  Phase map in `PLAN.md`.

## Falsifiers / What Would Defeat This

- Certification with any unresolved disagreement-register entry silently
  dropped.
- Runner green on a tip other than the tagged one (identity drift at the
  finish line).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | multi-repo (see PLAN.md) | current: 7 SATISFIED / 5 PARTIAL / 18 NOT-SATISFIED / 2 CLAIMED-UNVERIFIED / 12 UNKNOWN of 44 | all phases → audit → final runner → release record |
