---
{
  "identity": "GGEN_IGNITER-26922-05",
  "title": "Fix PR #25's CompileError ...",
  "description": "Fix PR #25's CompileError (`defp binding` conflicts with Kernel.binding/0 at test/ggen_igniter_semantic_jira_observation_delta_test.exs:8) and land the observation-delta work that marketplace #477 and ggen-ecosystem #350 consume. Acceptance: `mix test test/ggen_igniter_semantic_jira_observation_delta_test.exs test/ggen_igniter_semantic_jira_meeting_delta_test.exs` 0 failures and `gh pr checks 25 -R seanchatmangpt/ggen_igniter` shows no fail. Upstream work orders: GGEN_IGNITER-26922-03.",
  "subject": "seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-05",
  "repository": "seanchatmangpt/ggen_igniter",
  "base_sha": "facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "GGEN_IGNITER-26922-05 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-03) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:GGEN_IGNITER-26922-05",
  "required_courts": [
    "court-ggen-igniter-26922-05"
  ],
  "required_evidence": [
    "hosted-ci-evidence",
    "local-execution-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`mix test test/ggen_igniter_semantic_jira_observation_delta_test.exs test/ggen_igniter_semantic_jira_meeting_delta_test.exs` 0 failures and `gh pr checks 25 -R seanchatmangpt/ggen_igniter` shows no fail",
    "The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of GGEN_IGNITER-26922-05 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes GGEN_IGNITER-26922-05: at the court head, the test run reports one or more failures; or any listed check shows fail."
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
      "upstream": "GGEN_IGNITER-26922-03",
      "type": "requiresReceipt"
    }
  ],
  "path_scope": [
    "test/ggen_igniter_semantic_jira_meeting_delta_test.exs",
    "test/ggen_igniter_semantic_jira_observation_delta_test.exs"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification",
    "replay"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-05.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ggen-igniter-v26922-release"
}
---

# GGEN_IGNITER-26922-05: Fix PR #25's CompileError ...

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ggen_igniter @ `facdf0dbd3cd` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-05`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Fix PR #25's CompileError (`defp binding` conflicts with Kernel.binding/0 at test/ggen_igniter_semantic_jira_observation_delta_test.exs:8) and land the observation-delta work that marketplace #477 and ggen-ecosystem #350 consume. Acceptance: `mix test test/ggen_igniter_semantic_jira_observation_delta_test.exs test/ggen_igniter_semantic_jira_meeting_delta_test.exs` 0 failures and `gh pr checks 25 -R seanchatmangpt/ggen_igniter` shows no fail. Upstream work orders: GGEN_IGNITER-26922-03.

## Acceptance
- [ ] `mix test test/ggen_igniter_semantic_jira_observation_delta_test.exs test/ggen_igniter_semantic_jira_meeting_delta_test.exs` 0 failures and `gh pr checks 25 -R seanchatmangpt/ggen_igniter` shows no fail
- [ ] The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of GGEN_IGNITER-26922-05 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes GGEN_IGNITER-26922-05: at the court head, the test run reports one or more failures; or any listed check shows fail.

## Dependencies
- GGEN_IGNITER-26922-03 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-05.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
GGEN_IGNITER-26922-05 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-03) ALIVE. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
