---
{
  "identity": "GGEN_IGNITER-26922-14",
  "title": "Commit the day graph and generate docs/jira/v26.9.22, running once per calver-ticket-day-pack template",
  "description": "Commit the day graph and generate docs/jira/v26.9.22, running once per calver-ticket-day-pack template (`--pack calver-ticket-day-pack:ticket|runbook|runlog --out ...`). Acceptance: run twice, then `git diff --exit-code docs/jira/v26.9.22` exit 0, and the receipt's metadata.graph_hash equals \"sha256:\" plus sha256(day.ttl). Upstream work orders: GGEN_IGNITER-26922-01.",
  "subject": "seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-14",
  "repository": "seanchatmangpt/ggen_igniter",
  "base_sha": "facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "GGEN_IGNITER-26922-14 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-01) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:GGEN_IGNITER-26922-14",
  "required_courts": [
    "court-ggen-igniter-26922-14"
  ],
  "required_evidence": [
    "generated-artifact-evidence",
    "local-execution-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "run twice, then `git diff --exit-code docs/jira/v26.9.22` exit 0, and the receipt's metadata.graph_hash equals \"sha256:\" plus sha256(day.ttl)",
    "The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of GGEN_IGNITER-26922-14 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes GGEN_IGNITER-26922-14: at the court head, a command in the check exits nonzero; or a compared pair differs."
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
      "upstream": "GGEN_IGNITER-26922-01",
      "type": "requiresReceipt"
    }
  ],
  "path_scope": [
    "docs/jira/v26.9.22"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-14.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ggen-igniter-v26922-release"
}
---

# GGEN_IGNITER-26922-14: Commit the day graph and generate docs/jira/v26.9.22, running once per calver-ticket-day-pack template

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ggen_igniter @ `facdf0dbd3cd` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-14`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Commit the day graph and generate docs/jira/v26.9.22, running once per calver-ticket-day-pack template (`--pack calver-ticket-day-pack:ticket|runbook|runlog --out ...`). Acceptance: run twice, then `git diff --exit-code docs/jira/v26.9.22` exit 0, and the receipt's metadata.graph_hash equals "sha256:" plus sha256(day.ttl). Upstream work orders: GGEN_IGNITER-26922-01.

## Acceptance
- [ ] run twice, then `git diff --exit-code docs/jira/v26.9.22` exit 0, and the receipt's metadata.graph_hash equals "sha256:" plus sha256(day.ttl)
- [ ] The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of GGEN_IGNITER-26922-14 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes GGEN_IGNITER-26922-14: at the court head, a command in the check exits nonzero; or a compared pair differs.

## Dependencies
- GGEN_IGNITER-26922-01 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-14.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
GGEN_IGNITER-26922-14 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-01) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
