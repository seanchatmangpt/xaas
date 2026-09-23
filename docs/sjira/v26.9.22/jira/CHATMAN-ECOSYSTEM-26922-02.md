---
{
  "identity": "CHATMAN-ECOSYSTEM-26922-02",
  "title": "Jurisdiction contracts for the uncontracted loop participants",
  "description": "Jurisdiction contracts for the uncontracted loop participants (xaas, ggen_igniter, zcode-cli, ash_surface, dfcm-autonomous): edit the AGENTS.md table, JURISDICTION_TABLE/MUST_NOT_OWN, and test_jurisdiction_contracts.py:102 (13 -> 18). Acceptance: `python3.13 -m pytest prototype/tests -q` passes, including a new REFUSED_JURISDICTION_FORBIDDEN case for xaas. Upstream work orders: CHATMAN-ECOSYSTEM-26922-01. Non-order prerequisites: user-supplied Owns/Must-not-own values.",
  "subject": "local/chatman-ecosystem@release/v26.9.22#CHATMAN-ECOSYSTEM-26922-02",
  "repository": "local/chatman-ecosystem",
  "base_sha": "7ac66d8c55ce4aba62cd6416e9f3eecd358700e4",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "CHATMAN-ECOSYSTEM-26922-02 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on local/chatman-ecosystem release/v26.9.22 descended from 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (CHATMAN-ECOSYSTEM-26922-01) ALIVE, with the prerequisite evidence (user-supplied Owns/Must-not-own values) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:CHATMAN-ECOSYSTEM-26922-02",
  "required_courts": [
    "court-chatman-ecosystem-26922-02"
  ],
  "required_evidence": [
    "ev-chatman-ecosystem-26922-02-user-supplied-owns-must-not-own-values",
    "local-execution-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`python3.13 -m pytest prototype/tests -q` passes, including a new REFUSED_JURISDICTION_FORBIDDEN case for xaas",
    "The check runs at a recorded head of local/chatman-ecosystem release/v26.9.22 that has 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4 as an ancestor (git merge-base --is-ancestor 7ac66d8c55ce HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of CHATMAN-ECOSYSTEM-26922-02 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes CHATMAN-ECOSYSTEM-26922-02: at the court head, a named run, job or suite does not succeed."
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
    "AGENTS.md",
    "prototype/tests"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/chatman-ecosystem/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (7ac66d8c55ce), run the acceptance check, write receipts/v26.9.22/CHATMAN-ECOSYSTEM-26922-02.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-chatman-ecosystem-v26922-release"
}
---

# CHATMAN-ECOSYSTEM-26922-02: Jurisdiction contracts for the uncontracted loop participants

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: local/chatman-ecosystem @ `7ac66d8c55ce` (release/v26.9.22)
- **Subject**: `local/chatman-ecosystem@release/v26.9.22#CHATMAN-ECOSYSTEM-26922-02`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Jurisdiction contracts for the uncontracted loop participants (xaas, ggen_igniter, zcode-cli, ash_surface, dfcm-autonomous): edit the AGENTS.md table, JURISDICTION_TABLE/MUST_NOT_OWN, and test_jurisdiction_contracts.py:102 (13 -> 18). Acceptance: `python3.13 -m pytest prototype/tests -q` passes, including a new REFUSED_JURISDICTION_FORBIDDEN case for xaas. Upstream work orders: CHATMAN-ECOSYSTEM-26922-01. Non-order prerequisites: user-supplied Owns/Must-not-own values.

## Acceptance
- [ ] `python3.13 -m pytest prototype/tests -q` passes, including a new REFUSED_JURISDICTION_FORBIDDEN case for xaas
- [ ] The check runs at a recorded head of local/chatman-ecosystem release/v26.9.22 that has 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4 as an ancestor (git merge-base --is-ancestor 7ac66d8c55ce HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of CHATMAN-ECOSYSTEM-26922-02 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes CHATMAN-ECOSYSTEM-26922-02: at the court head, a named run, job or suite does not succeed.

## Dependencies
- CHATMAN-ECOSYSTEM-26922-01 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/chatman-ecosystem/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (7ac66d8c55ce), run the acceptance check, write receipts/v26.9.22/CHATMAN-ECOSYSTEM-26922-02.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
CHATMAN-ECOSYSTEM-26922-02 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on local/chatman-ecosystem release/v26.9.22 descended from 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (CHATMAN-ECOSYSTEM-26922-01) ALIVE, with the prerequisite evidence (user-supplied Owns/Must-not-own values) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
