---
{
  "identity": "GGEN_IGNITER-26922-08",
  "title": "Add a TTL-to-work-order loader and make descriptors a sync projection",
  "description": "Add a TTL-to-work-order loader and make descriptors a sync projection, closing the UNSUPPORTED(generator-capability) rows in /Users/sac/dev/zcode-cli/docs/sjira/v26.9.21/HANDWRITTEN.md. Acceptance: sync the descriptor projection twice over zcode work-orders.ttl into a scratch dir; output is byte-identical both times and equals Descriptor.build/4 for ZOCEL-001 (snapshot_digest reproduces). Upstream work orders: GGEN_IGNITER-26922-03.",
  "subject": "seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-08",
  "repository": "seanchatmangpt/ggen_igniter",
  "base_sha": "facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "GGEN_IGNITER-26922-08 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-03) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:GGEN_IGNITER-26922-08",
  "required_courts": [
    "court-ggen-igniter-26922-08"
  ],
  "required_evidence": [
    "generated-artifact-evidence",
    "local-execution-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "sync the descriptor projection twice over zcode work-orders.ttl into a scratch dir; output is byte-identical both times and equals Descriptor.build/4 for ZOCEL-001 (snapshot_digest reproduces)",
    "The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of GGEN_IGNITER-26922-08 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes GGEN_IGNITER-26922-08: at the court head, two runs over the same inputs differ in any byte; or a compared pair differs."
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
  "dependencies": [
    {
      "upstream": "GGEN_IGNITER-26922-03",
      "type": "requiresReceipt"
    }
  ],
  "path_scope": [
    "."
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-08.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ggen-igniter-v26922-release"
}
---

# GGEN_IGNITER-26922-08: Add a TTL-to-work-order loader and make descriptors a sync projection

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ggen_igniter @ `facdf0dbd3cd` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-08`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Add a TTL-to-work-order loader and make descriptors a sync projection, closing the UNSUPPORTED(generator-capability) rows in /Users/sac/dev/zcode-cli/docs/sjira/v26.9.21/HANDWRITTEN.md. Acceptance: sync the descriptor projection twice over zcode work-orders.ttl into a scratch dir; output is byte-identical both times and equals Descriptor.build/4 for ZOCEL-001 (snapshot_digest reproduces). Upstream work orders: GGEN_IGNITER-26922-03.

## Acceptance
- [ ] sync the descriptor projection twice over zcode work-orders.ttl into a scratch dir; output is byte-identical both times and equals Descriptor.build/4 for ZOCEL-001 (snapshot_digest reproduces)
- [ ] The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of GGEN_IGNITER-26922-08 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes GGEN_IGNITER-26922-08: at the court head, two runs over the same inputs differ in any byte; or a compared pair differs.

## Dependencies
- GGEN_IGNITER-26922-03 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-08.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
GGEN_IGNITER-26922-08 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-03) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
