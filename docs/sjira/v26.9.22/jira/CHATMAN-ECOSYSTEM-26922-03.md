---
{
  "identity": "CHATMAN-ECOSYSTEM-26922-03",
  "title": "Sigma alignment with the SA2A calculus (Observation -> Candidate -> Admission -> Authority -> Actuation -> Receipt -> Replay): add Candidate",
  "description": "Sigma alignment with the SA2A calculus (Observation -> Candidate -> Admission -> Authority -> Actuation -> Receipt -> Replay): add Candidate, Admission and Replay classes or explicit mappings to Possibility/Action, using zCoordinates from the shapes.ttl sh:in list, and update the pack.toml description. Acceptance: `bash scripts/validate_sigma.sh` exit 0, with the round-trip class count matching the new ontology. Upstream work orders: CHATMAN-ECOSYSTEM-26922-01.",
  "subject": "local/chatman-ecosystem@release/v26.9.22#CHATMAN-ECOSYSTEM-26922-03",
  "repository": "local/chatman-ecosystem",
  "base_sha": "7ac66d8c55ce4aba62cd6416e9f3eecd358700e4",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "CHATMAN-ECOSYSTEM-26922-03 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on local/chatman-ecosystem release/v26.9.22 descended from 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (CHATMAN-ECOSYSTEM-26922-01) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:CHATMAN-ECOSYSTEM-26922-03",
  "required_courts": [
    "court-chatman-ecosystem-26922-03"
  ],
  "required_evidence": [
    "local-execution-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`bash scripts/validate_sigma.sh` exit 0, with the round-trip class count matching the new ontology",
    "The check runs at a recorded head of local/chatman-ecosystem release/v26.9.22 that has 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4 as an ancestor (git merge-base --is-ancestor 7ac66d8c55ce HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of CHATMAN-ECOSYSTEM-26922-03 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes CHATMAN-ECOSYSTEM-26922-03: at the court head, a command in the check exits nonzero."
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
      "upstream": "CHATMAN-ECOSYSTEM-26922-01",
      "type": "requiresReceipt"
    }
  ],
  "path_scope": [
    "scripts/validate_sigma.sh"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/chatman-ecosystem/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (7ac66d8c55ce), run the acceptance check, write receipts/v26.9.22/CHATMAN-ECOSYSTEM-26922-03.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-chatman-ecosystem-v26922-release"
}
---

# CHATMAN-ECOSYSTEM-26922-03: Sigma alignment with the SA2A calculus (Observation -> Candidate -> Admission -> Authority -> Actuation -> Receipt -> Replay): add Candidate

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: local/chatman-ecosystem @ `7ac66d8c55ce` (release/v26.9.22)
- **Subject**: `local/chatman-ecosystem@release/v26.9.22#CHATMAN-ECOSYSTEM-26922-03`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Sigma alignment with the SA2A calculus (Observation -> Candidate -> Admission -> Authority -> Actuation -> Receipt -> Replay): add Candidate, Admission and Replay classes or explicit mappings to Possibility/Action, using zCoordinates from the shapes.ttl sh:in list, and update the pack.toml description. Acceptance: `bash scripts/validate_sigma.sh` exit 0, with the round-trip class count matching the new ontology. Upstream work orders: CHATMAN-ECOSYSTEM-26922-01.

## Acceptance
- [ ] `bash scripts/validate_sigma.sh` exit 0, with the round-trip class count matching the new ontology
- [ ] The check runs at a recorded head of local/chatman-ecosystem release/v26.9.22 that has 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4 as an ancestor (git merge-base --is-ancestor 7ac66d8c55ce HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of CHATMAN-ECOSYSTEM-26922-03 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes CHATMAN-ECOSYSTEM-26922-03: at the court head, a command in the check exits nonzero.

## Dependencies
- CHATMAN-ECOSYSTEM-26922-01 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/chatman-ecosystem/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (7ac66d8c55ce), run the acceptance check, write receipts/v26.9.22/CHATMAN-ECOSYSTEM-26922-03.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
CHATMAN-ECOSYSTEM-26922-03 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on local/chatman-ecosystem release/v26.9.22 descended from 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (CHATMAN-ECOSYSTEM-26922-01) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
