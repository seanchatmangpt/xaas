---
{
  "identity": "GGEN_IGNITER-26922-11",
  "title": "Flip the ash_a2a external_do row: bump the ash_a2a lock from 26.9.17 to 26.9.22 after ASH_A2A-26922-08 ships",
  "description": "Flip the ash_a2a external_do row: bump the ash_a2a lock from 26.9.17 to 26.9.22 after ASH_A2A-26922-08 ships, and land errc/external-do-capability. Acceptance: `mix test test/ggen_igniter_semantic_a2a_manufacture_test.exs && ! grep -n 'UNSUPPORTED(generator-capability): ash_a2a.install' priv/ggen/semantic-jira-pack/ontology.ttl`. Upstream work orders: GGEN_IGNITER-26922-04, ASH_A2A-26922-12.",
  "subject": "seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-11",
  "repository": "seanchatmangpt/ggen_igniter",
  "base_sha": "facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "GGEN_IGNITER-26922-11 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-04, ASH_A2A-26922-12) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:GGEN_IGNITER-26922-11",
  "required_courts": [
    "court-ggen-igniter-26922-11"
  ],
  "required_evidence": [
    "generated-artifact-evidence",
    "local-execution-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`mix test test/ggen_igniter_semantic_a2a_manufacture_test.exs && ! grep -n 'UNSUPPORTED(generator-capability): ash_a2a.install' priv/ggen/semantic-jira-pack/ontology.ttl`",
    "The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of GGEN_IGNITER-26922-11 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes GGEN_IGNITER-26922-11: at the court head, a command in the check exits nonzero (the check is its own exit status)."
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
      "upstream": "ASH_A2A-26922-12",
      "type": "requiresReceipt"
    },
    {
      "upstream": "GGEN_IGNITER-26922-04",
      "type": "requiresReceipt"
    }
  ],
  "path_scope": [
    "priv/ggen/semantic-jira-pack/ontology.ttl",
    "test/ggen_igniter_semantic_a2a_manufacture_test.exs"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-11.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ggen-igniter-v26922-release"
}
---

# GGEN_IGNITER-26922-11: Flip the ash_a2a external_do row: bump the ash_a2a lock from 26.9.17 to 26.9.22 after ASH_A2A-26922-08 ships

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ggen_igniter @ `facdf0dbd3cd` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-11`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Flip the ash_a2a external_do row: bump the ash_a2a lock from 26.9.17 to 26.9.22 after ASH_A2A-26922-08 ships, and land errc/external-do-capability. Acceptance: `mix test test/ggen_igniter_semantic_a2a_manufacture_test.exs && ! grep -n 'UNSUPPORTED(generator-capability): ash_a2a.install' priv/ggen/semantic-jira-pack/ontology.ttl`. Upstream work orders: GGEN_IGNITER-26922-04, ASH_A2A-26922-12.

## Acceptance
- [ ] `mix test test/ggen_igniter_semantic_a2a_manufacture_test.exs && ! grep -n 'UNSUPPORTED(generator-capability): ash_a2a.install' priv/ggen/semantic-jira-pack/ontology.ttl`
- [ ] The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of GGEN_IGNITER-26922-11 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes GGEN_IGNITER-26922-11: at the court head, a command in the check exits nonzero (the check is its own exit status).

## Dependencies
- ASH_A2A-26922-12 (requiresReceipt)
- GGEN_IGNITER-26922-04 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-11.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
GGEN_IGNITER-26922-11 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-04, ASH_A2A-26922-12) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
