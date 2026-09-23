---
{
  "identity": "FERROPLAN-26922-04",
  "title": "Bookkeeping: commit docs/jira/v26.9.19; close #43/#44 as landed; delete the superseded origin branches",
  "description": "Bookkeeping: commit docs/jira/v26.9.19; close #43/#44 as landed; delete the superseded origin branches (planning-type-constitution v1/v2, eve-genesis v1/v2, sync-upstream-c8d43f9); drop format-recovery.yml. Acceptance: `test \"$(gh pr list -R seanchatmangpt/ferroplan --state open --json number --jq length)\" -eq 0 && test -z \"$(git status --porcelain)\" && ! test -f .github/workflows/format-recovery.yml`. Upstream work orders: FERROPLAN-26922-01.",
  "subject": "seanchatmangpt/ferroplan@release/v26.9.22#FERROPLAN-26922-04",
  "repository": "seanchatmangpt/ferroplan",
  "base_sha": "305546927ebef3b188e79b2f497f8360f998f44b",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "FERROPLAN-26922-04 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ferroplan release/v26.9.22 descended from 305546927ebef3b188e79b2f497f8360f998f44b: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (FERROPLAN-26922-01) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:FERROPLAN-26922-04",
  "required_courts": [
    "court-ferroplan-26922-04"
  ],
  "required_evidence": [
    "hosted-ci-evidence",
    "local-execution-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`test \"$(gh pr list -R seanchatmangpt/ferroplan --state open --json number --jq length)\" -eq 0 && test -z \"$(git status --porcelain)\" && ! test -f .github/workflows/format-recovery.yml`",
    "The check runs at a recorded head of seanchatmangpt/ferroplan release/v26.9.22 that has 305546927ebef3b188e79b2f497f8360f998f44b as an ancestor (git merge-base --is-ancestor 305546927ebe HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of FERROPLAN-26922-04 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes FERROPLAN-26922-04: at the court head, a command in the check exits nonzero (the check is its own exit status)."
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
    ".github/workflows/format-recovery.yml",
    "docs/jira/v26.9.19"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ferroplan/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (305546927ebe), run the acceptance check, write receipts/v26.9.22/FERROPLAN-26922-04.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ferroplan-v26922-release"
}
---

# FERROPLAN-26922-04: Bookkeeping: commit docs/jira/v26.9.19; close #43/#44 as landed; delete the superseded origin branches

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ferroplan @ `305546927ebe` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ferroplan@release/v26.9.22#FERROPLAN-26922-04`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Bookkeeping: commit docs/jira/v26.9.19; close #43/#44 as landed; delete the superseded origin branches (planning-type-constitution v1/v2, eve-genesis v1/v2, sync-upstream-c8d43f9); drop format-recovery.yml. Acceptance: `test "$(gh pr list -R seanchatmangpt/ferroplan --state open --json number --jq length)" -eq 0 && test -z "$(git status --porcelain)" && ! test -f .github/workflows/format-recovery.yml`. Upstream work orders: FERROPLAN-26922-01.

## Acceptance
- [ ] `test "$(gh pr list -R seanchatmangpt/ferroplan --state open --json number --jq length)" -eq 0 && test -z "$(git status --porcelain)" && ! test -f .github/workflows/format-recovery.yml`
- [ ] The check runs at a recorded head of seanchatmangpt/ferroplan release/v26.9.22 that has 305546927ebef3b188e79b2f497f8360f998f44b as an ancestor (git merge-base --is-ancestor 305546927ebe HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of FERROPLAN-26922-04 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes FERROPLAN-26922-04: at the court head, a command in the check exits nonzero (the check is its own exit status).

## Dependencies
- FERROPLAN-26922-01 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/ferroplan/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (305546927ebe), run the acceptance check, write receipts/v26.9.22/FERROPLAN-26922-04.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
FERROPLAN-26922-04 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ferroplan release/v26.9.22 descended from 305546927ebef3b188e79b2f497f8360f998f44b: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (FERROPLAN-26922-01) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
