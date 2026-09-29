---
{
  "identity": "GGEN_IGNITER-26922-09",
  "title": "Record git HEAD in GgenIgniter.Receipt metadata",
  "description": "Record git HEAD in GgenIgniter.Receipt metadata. Acceptance: `mix test test/ggen_igniter_receipt_test.exs` passes, and after a sync `tail -1 .ggen_igniter/receipts/$(date +%F).jsonl | jq -r .metadata.git_head` equals `git rev-parse HEAD`.",
  "subject": "seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-09",
  "repository": "seanchatmangpt/ggen_igniter",
  "base_sha": "facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "GGEN_IGNITER-26922-09 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (none) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:GGEN_IGNITER-26922-09",
  "required_courts": [
    "court-ggen-igniter-26922-09"
  ],
  "required_evidence": [
    "local-execution-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`mix test test/ggen_igniter_receipt_test.exs` passes, and after a sync `tail -1 .ggen_igniter/receipts/$(date +%F).jsonl | jq -r .metadata.git_head` equals `git rev-parse HEAD`",
    "The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of GGEN_IGNITER-26922-09 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes GGEN_IGNITER-26922-09: at the court head, the two compared command outputs differ; or a compared pair differs; or a named run, job or suite does not succeed."
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
    ".ggen_igniter/receipts",
    "test/ggen_igniter_receipt_test.exs"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-09.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ggen-igniter-v26922-release"
}
---

# GGEN_IGNITER-26922-09: Record git HEAD in GgenIgniter.Receipt metadata

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ggen_igniter @ `facdf0dbd3cd` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-09`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Record git HEAD in GgenIgniter.Receipt metadata. Acceptance: `mix test test/ggen_igniter_receipt_test.exs` passes, and after a sync `tail -1 .ggen_igniter/receipts/$(date +%F).jsonl | jq -r .metadata.git_head` equals `git rev-parse HEAD`.

## Acceptance
- [ ] `mix test test/ggen_igniter_receipt_test.exs` passes, and after a sync `tail -1 .ggen_igniter/receipts/$(date +%F).jsonl | jq -r .metadata.git_head` equals `git rev-parse HEAD`
- [ ] The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of GGEN_IGNITER-26922-09 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes GGEN_IGNITER-26922-09: at the court head, the two compared command outputs differ; or a compared pair differs; or a named run, job or suite does not succeed.

## Dependencies
- none

## Next action
Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-09.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
GGEN_IGNITER-26922-09 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (none) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
