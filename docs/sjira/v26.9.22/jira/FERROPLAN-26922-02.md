---
{
  "identity": "FERROPLAN-26922-02",
  "title": "A deep lane that can pass: make the oracle and corpus durable",
  "description": "A deep lane that can pass: make the oracle and corpus durable (FERROPLAN_ORACLE_DIR/FERROPLAN_CORPUS_DIR defaulting to ~/.cache/ferroplan) so fond_flat_oracle, differential_fuzz, grounding_prune_ipc_rerun and ground_caps_ipc_addendum run or skip by name in CI; fix the Chatman Ecosystem projection-law job (CE-GALL-35 receipt stems and missing test refs). Acceptance: `gh run list -R seanchatmangpt/ferroplan --branch main --workflow CI -L1 --json conclusion -q '.[0].conclusion'` = success, and `(cd plugins/chatman-ecosystem && pytest)` exit 0. Upstream work orders: FERROPLAN-26922-01.",
  "subject": "seanchatmangpt/ferroplan@release/v26.9.22#FERROPLAN-26922-02",
  "repository": "seanchatmangpt/ferroplan",
  "base_sha": "305546927ebef3b188e79b2f497f8360f998f44b",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "FERROPLAN-26922-02 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ferroplan release/v26.9.22 descended from 305546927ebef3b188e79b2f497f8360f998f44b: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (FERROPLAN-26922-01) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:FERROPLAN-26922-02",
  "required_courts": [
    "court-ferroplan-26922-02"
  ],
  "required_evidence": [
    "generated-artifact-evidence",
    "hosted-ci-evidence",
    "local-execution-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`gh run list -R seanchatmangpt/ferroplan --branch main --workflow CI -L1 --json conclusion -q '.[0].conclusion'` = success, and `(cd plugins/chatman-ecosystem && pytest)` exit 0",
    "The check runs at a recorded head of seanchatmangpt/ferroplan release/v26.9.22 that has 305546927ebef3b188e79b2f497f8360f998f44b as an ancestor (git merge-base --is-ancestor 305546927ebe HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of FERROPLAN-26922-02 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes FERROPLAN-26922-02: at the court head, a command in the check exits nonzero; or a compared value is not success; or a named run, job or suite does not succeed."
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
      "upstream": "FERROPLAN-26922-01",
      "type": "requiresReceipt"
    }
  ],
  "path_scope": [
    "plugins/chatman-ecosystem"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ferroplan/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (305546927ebe), run the acceptance check, write receipts/v26.9.22/FERROPLAN-26922-02.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ferroplan-v26922-release"
}
---

# FERROPLAN-26922-02: A deep lane that can pass: make the oracle and corpus durable

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ferroplan @ `305546927ebe` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ferroplan@release/v26.9.22#FERROPLAN-26922-02`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
A deep lane that can pass: make the oracle and corpus durable (FERROPLAN_ORACLE_DIR/FERROPLAN_CORPUS_DIR defaulting to ~/.cache/ferroplan) so fond_flat_oracle, differential_fuzz, grounding_prune_ipc_rerun and ground_caps_ipc_addendum run or skip by name in CI; fix the Chatman Ecosystem projection-law job (CE-GALL-35 receipt stems and missing test refs). Acceptance: `gh run list -R seanchatmangpt/ferroplan --branch main --workflow CI -L1 --json conclusion -q '.[0].conclusion'` = success, and `(cd plugins/chatman-ecosystem && pytest)` exit 0. Upstream work orders: FERROPLAN-26922-01.

## Acceptance
- [ ] `gh run list -R seanchatmangpt/ferroplan --branch main --workflow CI -L1 --json conclusion -q '.[0].conclusion'` = success, and `(cd plugins/chatman-ecosystem && pytest)` exit 0
- [ ] The check runs at a recorded head of seanchatmangpt/ferroplan release/v26.9.22 that has 305546927ebef3b188e79b2f497f8360f998f44b as an ancestor (git merge-base --is-ancestor 305546927ebe HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of FERROPLAN-26922-02 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes FERROPLAN-26922-02: at the court head, a command in the check exits nonzero; or a compared value is not success; or a named run, job or suite does not succeed.

## Dependencies
- FERROPLAN-26922-01 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/ferroplan/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (305546927ebe), run the acceptance check, write receipts/v26.9.22/FERROPLAN-26922-02.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
FERROPLAN-26922-02 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ferroplan release/v26.9.22 descended from 305546927ebef3b188e79b2f497f8360f998f44b: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (FERROPLAN-26922-01) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
