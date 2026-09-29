---
{
  "identity": "GGEN_IGNITER-26922-13",
  "title": "Release v26.9.22: mix.exs 26.9.20 -> 26.9.22, CHANGELOG top heading, tag, hex publish (hex currently tops out at 26.9.15)",
  "description": "Release v26.9.22: mix.exs 26.9.20 -> 26.9.22, CHANGELOG top heading, tag, hex publish (hex currently tops out at 26.9.15). Acceptance: `mix ggen_igniter.doctor` exit 0 (check 17); `git ls-remote --tags origin v26.9.22 | wc -l` = 1; `curl -s https://hex.pm/api/packages/ggen_igniter | jq -r '.releases[0].version'` = 26.9.22. Upstream work orders: GGEN_IGNITER-26922-10. Non-order prerequisites: publish authority.",
  "subject": "seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-13",
  "repository": "seanchatmangpt/ggen_igniter",
  "base_sha": "facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "authority_ceiling": "CONSTRUCT",
  "authority_requirement": "NONE",
  "promotion_rule": "GGEN_IGNITER-26922-13 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-10) ALIVE, with the prerequisite evidence (publish authority) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.",
  "replay_identity": "semantic-jira:v26.9.22:GGEN_IGNITER-26922-13",
  "required_courts": [
    "court-ggen-igniter-26922-13"
  ],
  "required_evidence": [
    "authority-evidence",
    "ev-ggen-igniter-26922-13-publish-authority",
    "local-execution-evidence",
    "publication-evidence",
    "receipt-evidence",
    "replay-evidence",
    "source-evidence"
  ],
  "acceptance": [
    "`mix ggen_igniter.doctor` exit 0 (check 17); `git ls-remote --tags origin v26.9.22 | wc -l` = 1; `curl -s https://hex.pm/api/packages/ggen_igniter | jq -r '.releases[0].version'` = 26.9.22",
    "The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha."
  ],
  "falsifiers": [
    "Refutes the acceptance of GGEN_IGNITER-26922-13 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.",
    "Refutes GGEN_IGNITER-26922-13: at the court head, a command in the check exits nonzero; or a compared value is not 1; or a compared value is not 26.9.22."
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
      "upstream": "GGEN_IGNITER-26922-10",
      "type": "requiresReceipt"
    }
  ],
  "path_scope": [
    "mix.exs"
  ],
  "required_receipt_classes": [
    "manufacture",
    "authority_preparation",
    "verification",
    "replay",
    "publication"
  ],
  "next_action": "Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-13.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.",
  "next_checkpoint": "cp-ggen-igniter-v26922-release"
}
---

# GGEN_IGNITER-26922-13: Release v26.9.22: mix.exs 26.9.20 -> 26.9.22, CHANGELOG top heading, tag, hex publish (hex currently tops out at 26.9.15)

- **Standing**: UNKNOWN (projected from work-orders.ttl; observed standing comes from the TransitionLog)
- **Repository**: seanchatmangpt/ggen_igniter @ `facdf0dbd3cd` (release/v26.9.22)
- **Subject**: `seanchatmangpt/ggen_igniter@release/v26.9.22#GGEN_IGNITER-26922-13`
- **Authority**: ceiling CONSTRUCT, requirement NONE

## Description
Release v26.9.22: mix.exs 26.9.20 -> 26.9.22, CHANGELOG top heading, tag, hex publish (hex currently tops out at 26.9.15). Acceptance: `mix ggen_igniter.doctor` exit 0 (check 17); `git ls-remote --tags origin v26.9.22 | wc -l` = 1; `curl -s https://hex.pm/api/packages/ggen_igniter | jq -r '.releases[0].version'` = 26.9.22. Upstream work orders: GGEN_IGNITER-26922-10. Non-order prerequisites: publish authority.

## Acceptance
- [ ] `mix ggen_igniter.doctor` exit 0 (check 17); `git ls-remote --tags origin v26.9.22 | wc -l` = 1; `curl -s https://hex.pm/api/packages/ggen_igniter | jq -r '.releases[0].version'` = 26.9.22
- [ ] The check runs at a recorded head of seanchatmangpt/ggen_igniter release/v26.9.22 that has facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc as an ancestor (git merge-base --is-ancestor facdf0dbd3cd HEAD exits 0); that head is the receipt subjectSha.

## Falsifiers
- Refutes the acceptance of GGEN_IGNITER-26922-13 as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.
- Refutes GGEN_IGNITER-26922-13: at the court head, a command in the check exits nonzero; or a compared value is not 1; or a compared value is not 26.9.22.

## Dependencies
- GGEN_IGNITER-26922-10 (requiresReceipt)

## Next action
Take /Users/sac/wt/v26922/ggen_igniter/.merge.lock per COORDINATION.md, build in an own worktree off release/v26.9.22 (facdf0dbd3cd), run the acceptance check, write receipts/v26.9.22/GGEN_IGNITER-26922-13.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.

## Promotion rule
GGEN_IGNITER-26922-13 leaves UNKNOWN only through a TransitionLog event whose receipt binds candidateSha and subjectSha on seanchatmangpt/ggen_igniter release/v26.9.22 descended from facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc: the court must observe the acceptance check pass at that head, observe it fail when the order's diff is reverted (revert-mutation), and find every upstream edge (GGEN_IGNITER-26922-10) ALIVE, with the prerequisite evidence (publish authority) recorded. A passing log without a receipt, a generated projection, or upstream standing alone never promotes.
