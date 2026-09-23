---
{
  "identity": "FERROPLAN-26922-08",
  "title": "integration/all-open-prs-2026-07-31 (69 unique patches: the v26.8.1 ggen full_planning graph)",
  "description": "integration/all-open-prs-2026-07-31 (69 unique patches: the v26.8.1 ggen full_planning graph): land it by merge or delete it with a rationale recorded in v26.9.19 tickets 008/009. Acceptance: `(git merge-base --is-ancestor 18dbc73 main || ! git ls-remote --exit-code origin refs/heads/integration/all-open-prs-2026-07-31) && grep -Eq 'Standing: (CLOSED|DONE|ALIVE)' docs/jira/v26.9.19/008-*.md docs/jira/v26.9.19/009-*.md`.",
  "subject": "seanchatmangpt/ferroplan@release/v26.9.22#FERROPLAN-26922-08",
  "repository": "seanchatmangpt/ferroplan",
  "base_sha": "305546927ebef3b188e79b2f497f8360f998f44b",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "FERROPLAN-26922-08 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ferroplan release/v26.9.22 descended from 305546927ebef3b188e79b2f497f8360f998f44b: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (none) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:FERROPLAN-26922-08",
  "required_courts": [
    "court-ferroplan-26922-08"
  ],
  "required_evidence": [
    "local-execution-evidence",
    "postcondition-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`(git merge-base --is-ancestor 18dbc73 main || ! git ls-remote --exit-code origin refs/heads/integration/all-open-prs-2026-07-31) && grep -Eq 'Standing: (CLOSED|DONE|ALIVE)' docs/jira/v26.9.19/008-*.md docs/jira/v26.9.19/009-*.md`",
    "The check runs at a recorded head of seanchatmangpt/ferroplan release/v26.9.22 that has 305546927ebef3b188e79b2f497f8360f998f44b as an ancestor (git merge-base --is-ancestor 305546927ebe HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of FERROPLAN-26922-08 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes FERROPLAN-26922-08: at the court head, a command in the check exits nonzero (the check is its own exit status)."
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
    "docs/jira/v26.9.19/008-.md",
    "docs/jira/v26.9.19/009-.md"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "postcondition",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ferroplan/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (305546927ebe), run the acceptance check, write receipts/v26.9.22/FERROPLAN-26922-08.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ferroplan-v26922-release"
}
---

# FERROPLAN-26922-08: integration/all-open-prs-2026-07-31 (69 unique patches: the v26.8.1 ggen full_planning graph)

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ferroplan @ `305546927ebe` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ferroplan@release/v26.9.22#FERROPLAN-26922-08`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
integration/all-open-prs-2026-07-31 (69 unique patches: the v26.8.1 ggen full_planning graph): land it by merge or delete it with a rationale recorded in v26.9.19 tickets 008/009. Acceptance: `(git merge-base --is-ancestor 18dbc73 main || ! git ls-remote --exit-code origin refs/heads/integration/all-open-prs-2026-07-31) && grep -Eq 'Standing: (CLOSED|DONE|ALIVE)' docs/jira/v26.9.19/008-*.md docs/jira/v26.9.19/009-*.md`.

## Acceptance
- [ ] `(git merge-base --is-ancestor 18dbc73 main || ! git ls-remote --exit-code origin refs/heads/integration/all-open-prs-2026-07-31) && grep -Eq 'Standing: (CLOSED|DONE|ALIVE)' docs/jira/v26.9.19/008-*.md docs/jira/v26.9.19/009-*.md`
- [ ] The check runs at a recorded head of seanchatmangpt/ferroplan release/v26.9.22 that has 305546927ebef3b188e79b2f497f8360f998f44b as an ancestor (git merge-base --is-ancestor 305546927ebe HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of FERROPLAN-26922-08 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes FERROPLAN-26922-08: at the court head, a command in the check exits nonzero (the check is its own exit status).

## Dependencies
- none

## Next action
Take /Users/sac/wt/v26922/ferroplan/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (305546927ebe), run the acceptance check, write receipts/v26.9.22/FERROPLAN-26922-08.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
FERROPLAN-26922-08 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ferroplan release/v26.9.22 descended from 305546927ebef3b188e79b2f497f8360f998f44b: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (none) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
