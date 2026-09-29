---
{
  "identity": "FERROPLAN-26922-03",
  "title": "Rule on fond-htn-67: vendor autofde-lab's sa2a-v26.9.17 domain and problem",
  "description": "Rule on fond-htn-67: vendor autofde-lab's sa2a-v26.9.17 domain and problem (no :goal, htn root only), run it fresh at HEAD, and record ruling (a), or implement (b) as a flag-gated accepted-terminal mode that is byte-identical with the flag off. Acceptance: `cargo test -p ferroplan --test sa2a_goal_set_ruling && cargo test -p ferroplan --lib planning_runtime` exit 0, and `git ls-files --error-unmatch docs/jira/v26.9.17/fond-htn-67-sa2a-goal-set-semantics-divergence.md` succeeds with a new dated standing row. Upstream work orders: FERROPLAN-26922-01. Non-order prerequisites: user ruling.",
  "subject": "seanchatmangpt/ferroplan@release/v26.9.22#FERROPLAN-26922-03",
  "repository": "seanchatmangpt/ferroplan",
  "base_sha": "305546927ebef3b188e79b2f497f8360f998f44b",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "FERROPLAN-26922-03 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ferroplan release/v26.9.22 descended from 305546927ebef3b188e79b2f497f8360f998f44b: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (FERROPLAN-26922-01) ALIVE, with the prerequisite evidence (user ruling) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:FERROPLAN-26922-03",
  "required_courts": [
    "court-ferroplan-26922-03"
  ],
  "required_evidence": [
    "ev-ferroplan-26922-03-user-ruling",
    "local-execution-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`cargo test -p ferroplan --test sa2a_goal_set_ruling && cargo test -p ferroplan --lib planning_runtime` exit 0, and `git ls-files --error-unmatch docs/jira/v26.9.17/fond-htn-67-sa2a-goal-set-semantics-divergence.md` succeeds with a new dated standing row",
    "The check runs at a recorded head of seanchatmangpt/ferroplan release/v26.9.22 that has 305546927ebef3b188e79b2f497f8360f998f44b as an ancestor (git merge-base --is-ancestor 305546927ebe HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of FERROPLAN-26922-03 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes FERROPLAN-26922-03: at the court head, a command in the check exits nonzero; or a named run, job or suite does not succeed."
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
    "docs/jira/v26.9.17/fond-htn-67-sa2a-goal-set-semantics-divergence.md"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ferroplan/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (305546927ebe), run the acceptance check, write receipts/v26.9.22/FERROPLAN-26922-03.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ferroplan-v26922-release"
}
---

# FERROPLAN-26922-03: Rule on fond-htn-67: vendor autofde-lab's sa2a-v26.9.17 domain and problem

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ferroplan @ `305546927ebe` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ferroplan@release/v26.9.22#FERROPLAN-26922-03`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Rule on fond-htn-67: vendor autofde-lab's sa2a-v26.9.17 domain and problem (no :goal, htn root only), run it fresh at HEAD, and record ruling (a), or implement (b) as a flag-gated accepted-terminal mode that is byte-identical with the flag off. Acceptance: `cargo test -p ferroplan --test sa2a_goal_set_ruling && cargo test -p ferroplan --lib planning_runtime` exit 0, and `git ls-files --error-unmatch docs/jira/v26.9.17/fond-htn-67-sa2a-goal-set-semantics-divergence.md` succeeds with a new dated standing row. Upstream work orders: FERROPLAN-26922-01. Non-order prerequisites: user ruling.

## Acceptance
- [ ] `cargo test -p ferroplan --test sa2a_goal_set_ruling && cargo test -p ferroplan --lib planning_runtime` exit 0, and `git ls-files --error-unmatch docs/jira/v26.9.17/fond-htn-67-sa2a-goal-set-semantics-divergence.md` succeeds with a new dated standing row
- [ ] The check runs at a recorded head of seanchatmangpt/ferroplan release/v26.9.22 that has 305546927ebef3b188e79b2f497f8360f998f44b as an ancestor (git merge-base --is-ancestor 305546927ebe HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of FERROPLAN-26922-03 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes FERROPLAN-26922-03: at the court head, a command in the check exits nonzero; or a named run, job or suite does not succeed.

## Dependencies
- FERROPLAN-26922-01 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/ferroplan/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (305546927ebe), run the acceptance check, write receipts/v26.9.22/FERROPLAN-26922-03.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
FERROPLAN-26922-03 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ferroplan release/v26.9.22 descended from 305546927ebef3b188e79b2f497f8360f998f44b: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (FERROPLAN-26922-01) ALIVE, with the prerequisite evidence (user ruling) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
