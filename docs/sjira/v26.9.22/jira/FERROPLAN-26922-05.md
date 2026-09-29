---
{
  "identity": "FERROPLAN-26922-05",
  "title": "Merge upstream hhh42 main, re-resolved via `git ls-remote upstream refs/heads/main` at execution time because the 0.28 cut is in progress",
  "description": "Merge upstream hhh42 main, re-resolved via `git ls-remote upstream refs/heads/main` at execution time because the 0.28 cut is in progress. Acceptance: `git fetch upstream && git merge-base --is-ancestor $(git ls-remote upstream refs/heads/main | cut -f1) main && cargo fmt --all -- --check && cargo clippy --workspace --exclude ferroplan-bevy --all-targets --all-features -- -D warnings && cargo test --workspace --exclude ferroplan-bevy && (cd crucible && cargo test)` exit 0. Upstream work orders: FERROPLAN-26922-02. Non-order prerequisites: user version decision.",
  "subject": "seanchatmangpt/ferroplan@release/v26.9.22#FERROPLAN-26922-05",
  "repository": "seanchatmangpt/ferroplan",
  "base_sha": "305546927ebef3b188e79b2f497f8360f998f44b",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "FERROPLAN-26922-05 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ferroplan release/v26.9.22 descended from 305546927ebef3b188e79b2f497f8360f998f44b: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (FERROPLAN-26922-02) ALIVE, with the prerequisite evidence (user version decision) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:FERROPLAN-26922-05",
  "required_courts": [
    "court-ferroplan-26922-05"
  ],
  "required_evidence": [
    "ev-ferroplan-26922-05-user-version-decision",
    "local-execution-evidence",
    "postcondition-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`git fetch upstream && git merge-base --is-ancestor $(git ls-remote upstream refs/heads/main | cut -f1) main && cargo fmt --all -- --check && cargo clippy --workspace --exclude ferroplan-bevy --all-targets --all-features -- -D warnings && cargo test --workspace --exclude ferroplan-bevy && (cd crucible && cargo test)` exit 0",
    "The check runs at a recorded head of seanchatmangpt/ferroplan release/v26.9.22 that has 305546927ebef3b188e79b2f497f8360f998f44b as an ancestor (git merge-base --is-ancestor 305546927ebe HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of FERROPLAN-26922-05 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes FERROPLAN-26922-05: at the court head, a command in the check exits nonzero."
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
      "upstream": "FERROPLAN-26922-02",
      "type": "requiresReceipt"
    }
  ],
  "path_scope": [
    "."
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "postcondition",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ferroplan/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (305546927ebe), run the acceptance check, write receipts/v26.9.22/FERROPLAN-26922-05.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ferroplan-v26922-release"
}
---

# FERROPLAN-26922-05: Merge upstream hhh42 main, re-resolved via `git ls-remote upstream refs/heads/main` at execution time because the 0.28 cut is in progress

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ferroplan @ `305546927ebe` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ferroplan@release/v26.9.22#FERROPLAN-26922-05`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Merge upstream hhh42 main, re-resolved via `git ls-remote upstream refs/heads/main` at execution time because the 0.28 cut is in progress. Acceptance: `git fetch upstream && git merge-base --is-ancestor $(git ls-remote upstream refs/heads/main | cut -f1) main && cargo fmt --all -- --check && cargo clippy --workspace --exclude ferroplan-bevy --all-targets --all-features -- -D warnings && cargo test --workspace --exclude ferroplan-bevy && (cd crucible && cargo test)` exit 0. Upstream work orders: FERROPLAN-26922-02. Non-order prerequisites: user version decision.

## Acceptance
- [ ] `git fetch upstream && git merge-base --is-ancestor $(git ls-remote upstream refs/heads/main | cut -f1) main && cargo fmt --all -- --check && cargo clippy --workspace --exclude ferroplan-bevy --all-targets --all-features -- -D warnings && cargo test --workspace --exclude ferroplan-bevy && (cd crucible && cargo test)` exit 0
- [ ] The check runs at a recorded head of seanchatmangpt/ferroplan release/v26.9.22 that has 305546927ebef3b188e79b2f497f8360f998f44b as an ancestor (git merge-base --is-ancestor 305546927ebe HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of FERROPLAN-26922-05 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes FERROPLAN-26922-05: at the court head, a command in the check exits nonzero.

## Dependencies
- FERROPLAN-26922-02 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/ferroplan/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (305546927ebe), run the acceptance check, write receipts/v26.9.22/FERROPLAN-26922-05.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
FERROPLAN-26922-05 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ferroplan release/v26.9.22 descended from 305546927ebef3b188e79b2f497f8360f998f44b: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (FERROPLAN-26922-02) ALIVE, with the prerequisite evidence (user version decision) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
