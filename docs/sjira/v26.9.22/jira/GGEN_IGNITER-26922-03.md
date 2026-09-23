---
{
  "identity": "GGEN_IGNITER-26922-03",
  "title": "Restore content dropped by the six ours-strategy merges",
  "description": "Restore content dropped by the six ours-strategy merges (38596ce, 1b586f9, 8fc6ce6, 4ffa201, 76279a9, 070dbd5) according to the chosen canonical lineage, by cherry-picking each discarded range and resolving by hand, then merge 3edd2ec/e20c552/8032dab/186c74c. Acceptance: `cd /Users/sac/ggen_igniter && for s in 3edd2ec e20c552 8032dab 186c74c; do git merge-base --is-ancestor $s HEAD || echo MISSING $s; done; test -f lib/ggen_igniter/crown.ex || test -f docs/supersession/crown.md; [ $(grep -c oslc_cm priv/ggen/semantic-jira-pack/ontology.ttl) -gt 0 ] || test -f docs/supersession/adr-011.md; mix test` gives 0 failures and no MISSING lines. Upstream work orders: GGEN_IGNITER-26922-01, GGEN_IGNITER-26922-02. Non-order prerequisites: user lineage decision.",
  "subject": "seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-03",
  "repository": "seanchatmangpt/ggen_igniter",
  "base_sha": "facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "GGEN_IGNITER-26922-03 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-01, GGEN_IGNITER-26922-02) ALIVE, with the prerequisite evidence (user lineage decision) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:GGEN_IGNITER-26922-03",
  "required_courts": [
    "court-ggen-igniter-26922-03"
  ],
  "required_evidence": [
    "ev-ggen-igniter-26922-03-user-lineage-decision",
    "local-execution-evidence",
    "postcondition-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`cd /Users/sac/ggen_igniter && for s in 3edd2ec e20c552 8032dab 186c74c; do git merge-base --is-ancestor $s HEAD || echo MISSING $s; done; test -f lib/ggen_igniter/crown.ex || test -f docs/supersession/crown.md; [ $(grep -c oslc_cm priv/ggen/semantic-jira-pack/ontology.ttl) -gt 0 ] || test -f docs/supersession/adr-011.md; mix test` gives 0 failures and no MISSING lines",
    "The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of GGEN_IGNITER-26922-03 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes GGEN_IGNITER-26922-03: at the court head, the check prints any line or match (for example a MISSING/STALE marker); or the test run reports one or more failures."
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
    },
    {
      "upstream": "GGEN_IGNITER-26922-02",
      "type": "requiresReceipt"
    }
  ],
  "path_scope": [
    "lib/ggen_igniter/crown.ex",
    "priv/ggen/semantic-jira-pack/ontology.ttl"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "postcondition",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-03.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ggen-igniter-v26922-release"
}
---

# GGEN_IGNITER-26922-03: Restore content dropped by the six ours-strategy merges

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ggen_igniter @ `facdf0dbd3cd` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-03`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Restore content dropped by the six ours-strategy merges (38596ce, 1b586f9, 8fc6ce6, 4ffa201, 76279a9, 070dbd5) according to the chosen canonical lineage, by cherry-picking each discarded range and resolving by hand, then merge 3edd2ec/e20c552/8032dab/186c74c. Acceptance: `cd /Users/sac/ggen_igniter && for s in 3edd2ec e20c552 8032dab 186c74c; do git merge-base --is-ancestor $s HEAD || echo MISSING $s; done; test -f lib/ggen_igniter/crown.ex || test -f docs/supersession/crown.md; [ $(grep -c oslc_cm priv/ggen/semantic-jira-pack/ontology.ttl) -gt 0 ] || test -f docs/supersession/adr-011.md; mix test` gives 0 failures and no MISSING lines. Upstream work orders: GGEN_IGNITER-26922-01, GGEN_IGNITER-26922-02. Non-order prerequisites: user lineage decision.

## Acceptance
- [ ] `cd /Users/sac/ggen_igniter && for s in 3edd2ec e20c552 8032dab 186c74c; do git merge-base --is-ancestor $s HEAD || echo MISSING $s; done; test -f lib/ggen_igniter/crown.ex || test -f docs/supersession/crown.md; [ $(grep -c oslc_cm priv/ggen/semantic-jira-pack/ontology.ttl) -gt 0 ] || test -f docs/supersession/adr-011.md; mix test` gives 0 failures and no MISSING lines
- [ ] The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of GGEN_IGNITER-26922-03 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes GGEN_IGNITER-26922-03: at the court head, the check prints any line or match (for example a MISSING/STALE marker); or the test run reports one or more failures.

## Dependencies
- GGEN_IGNITER-26922-01 (requiresReceipt)
- GGEN_IGNITER-26922-02 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-03.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
GGEN_IGNITER-26922-03 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-01, GGEN_IGNITER-26922-02) ALIVE, with the prerequisite evidence (user lineage decision) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
