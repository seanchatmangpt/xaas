---
{
  "identity": "GGEN_IGNITER-26922-01",
  "title": "Sync refs: fetch the 6 missing heads and fast-forward local main",
  "description": "Sync refs: fetch the 6 missing heads and fast-forward local main. Acceptance: `cd /Users/sac/ggen_igniter && git fetch origin && git fetch origin main:main && git merge-base --is-ancestor origin/main main && for s in f283790 e20c552 3edd2ec 775d0f3 8032dab 186c74c; do git cat-file -e $s^{commit} || echo MISSING $s; done` prints nothing.",
  "subject": "seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-01",
  "repository": "seanchatmangpt/ggen_igniter",
  "base_sha": "facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "GGEN_IGNITER-26922-01 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (none) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:GGEN_IGNITER-26922-01",
  "required_courts": [
    "court-ggen-igniter-26922-01"
  ],
  "required_evidence": [
    "local-execution-evidence",
    "postcondition-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`cd /Users/sac/ggen_igniter && git fetch origin && git fetch origin main:main && git merge-base --is-ancestor origin/main main && for s in f283790 e20c552 3edd2ec 775d0f3 8032dab 186c74c; do git cat-file -e $s^{commit} || echo MISSING $s; done` prints nothing",
    "The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of GGEN_IGNITER-26922-01 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes GGEN_IGNITER-26922-01: at the court head, the check prints any line or match (for example a MISSING/STALE marker)."
  ],
  "projections": [
    "jira",
    "sa2a",
    "worker",
    "verification",
    "machine",
    "receipt",
    "replay"
  ],
  "dependencies": [],
  "path_scope": [
    "."
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "postcondition",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-01.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ggen-igniter-v26922-release"
}
---

# GGEN_IGNITER-26922-01: Sync refs: fetch the 6 missing heads and fast-forward local main

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ggen_igniter @ `facdf0dbd3cd` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-01`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Sync refs: fetch the 6 missing heads and fast-forward local main. Acceptance: `cd /Users/sac/ggen_igniter && git fetch origin && git fetch origin main:main && git merge-base --is-ancestor origin/main main && for s in f283790 e20c552 3edd2ec 775d0f3 8032dab 186c74c; do git cat-file -e $s^{commit} || echo MISSING $s; done` prints nothing.

## Acceptance
- [ ] `cd /Users/sac/ggen_igniter && git fetch origin && git fetch origin main:main && git merge-base --is-ancestor origin/main main && for s in f283790 e20c552 3edd2ec 775d0f3 8032dab 186c74c; do git cat-file -e $s^{commit} || echo MISSING $s; done` prints nothing
- [ ] The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of GGEN_IGNITER-26922-01 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes GGEN_IGNITER-26922-01: at the court head, the check prints any line or match (for example a MISSING/STALE marker).

## Dependencies
- none

## Next action
Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-01.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
GGEN_IGNITER-26922-01 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (none) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
