---
{
  "identity": "CHATMAN-ECOSYSTEM-26922-01",
  "title": "Land the 2026-09-21 doc refresh (an operator cut). Record the base SHA and gate results, not a self-referential HEAD",
  "description": "Land the 2026-09-21 doc refresh (an operator cut). Record the base SHA and gate results, not a self-referential HEAD. Acceptance: `cd /Users/sac/chatman-ecosystem && bash scripts/validate_sigma.sh && python3.13 -m pytest prototype/tests -q && python3.13 prototype/demo.py && test -z \"$(git status --porcelain)\"` exit 0. Non-order prerequisites: operator authority.",
  "subject": "local/chatman-ecosystem@release/v26.9.22#CHATMAN-ECOSYSTEM-26922-01",
  "repository": "local/chatman-ecosystem",
  "base_sha": "7ac66d8c55ce4aba62cd6416e9f3eecd358700e4",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "CHATMAN-ECOSYSTEM-26922-01 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on local/chatman-ecosystem release/v26.9.22 descended from 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (none) ALIVE, with the prerequisite evidence (operator authority) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:CHATMAN-ECOSYSTEM-26922-01",
  "required_courts": [
    "court-chatman-ecosystem-26922-01"
  ],
  "required_evidence": [
    "authority-evidence",
    "ev-chatman-ecosystem-26922-01-operator-authority",
    "local-execution-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`cd /Users/sac/chatman-ecosystem && bash scripts/validate_sigma.sh && python3.13 -m pytest prototype/tests -q && python3.13 prototype/demo.py && test -z \"$(git status --porcelain)\"` exit 0",
    "The check runs at a recorded head of local/chatman-ecosystem release/v26.9.22 that has 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4 as an ancestor (git merge-base --is-ancestor 7ac66d8c55ce HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of CHATMAN-ECOSYSTEM-26922-01 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes CHATMAN-ECOSYSTEM-26922-01: at the court head, a command in the check exits nonzero."
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
    "prototype/demo.py",
    "prototype/tests",
    "scripts/validate_sigma.sh"
  ],
  "required_receipt_classes": [
    "manufacture",
    "authority_preparation",
    "verification",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/chatman-ecosystem/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (7ac66d8c55ce), run the acceptance check, write receipts/v26.9.22/CHATMAN-ECOSYSTEM-26922-01.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-chatman-ecosystem-v26922-release"
}
---

# CHATMAN-ECOSYSTEM-26922-01: Land the 2026-09-21 doc refresh (an operator cut). Record the base SHA and gate results, not a self-referential HEAD

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: local/chatman-ecosystem @ `7ac66d8c55ce` (release/v26.9.22)
- **Subject**: `local/chatman-ecosystem@release/v26.9.22#CHATMAN-ECOSYSTEM-26922-01`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Land the 2026-09-21 doc refresh (an operator cut). Record the base SHA and gate results, not a self-referential HEAD. Acceptance: `cd /Users/sac/chatman-ecosystem && bash scripts/validate_sigma.sh && python3.13 -m pytest prototype/tests -q && python3.13 prototype/demo.py && test -z "$(git status --porcelain)"` exit 0. Non-order prerequisites: operator authority.

## Acceptance
- [ ] `cd /Users/sac/chatman-ecosystem && bash scripts/validate_sigma.sh && python3.13 -m pytest prototype/tests -q && python3.13 prototype/demo.py && test -z "$(git status --porcelain)"` exit 0
- [ ] The check runs at a recorded head of local/chatman-ecosystem release/v26.9.22 that has 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4 as an ancestor (git merge-base --is-ancestor 7ac66d8c55ce HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of CHATMAN-ECOSYSTEM-26922-01 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes CHATMAN-ECOSYSTEM-26922-01: at the court head, a command in the check exits nonzero.

## Dependencies
- none

## Next action
Take /Users/sac/wt/v26922/chatman-ecosystem/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (7ac66d8c55ce), run the acceptance check, write receipts/v26.9.22/CHATMAN-ECOSYSTEM-26922-01.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
CHATMAN-ECOSYSTEM-26922-01 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on local/chatman-ecosystem release/v26.9.22 descended from 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (none) ALIVE, with the prerequisite evidence (operator authority) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
