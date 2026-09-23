---
{
  "acceptance": [
    "merge-base is-ancestor upstream-main main; fmt, clippy, workspace tests, crucible tests pass"
  ],
  "authority_requirement": "OPERATOR_DECISION_REQUIRED",
  "base_sha": "e90928d7b0687a959831553c4eacca3d75ca6c88",
  "dependencies": [
    {
      "type": "requiresReceipt",
      "upstream": "FERROPLAN-26922-02"
    }
  ],
  "description": "Re-resolve the ref at execution time (0.28 cut in progress); version/tag collision needs a user decision.",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "falsifiers": [
    "consequential transition actuated without fresh operator-supplied authority",
    "evidence claimed without a durable receipt binding the subject SHA",
    "standing promoted without observing the acceptance command's exit 0 against the exact subject"
  ],
  "identity": "FERROPLAN-26922-5",
  "path_scope": [
    "crates/**"
  ],
  "projections": [
    "jira",
    "receipt",
    "verification"
  ],
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.22-FERROPLAN-26922-5",
  "repository": "seanchatmangpt/ferroplan",
  "required_courts": [
    "compile",
    "tests"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ],
  "standing": "UNKNOWN",
  "subject": "merge-upstream",
  "title": "Merge upstream hhh42 main"
}
---

# FERROPLAN-26922-5: Merge upstream hhh42 main

- **Standing**: UNKNOWN
- **Repository**: seanchatmangpt/ferroplan @ `e90928d`
- **Authority requirement**: OPERATOR_DECISION_REQUIRED

- **Requires receipt of**: FERROPLAN-26922-02 (requiresReceipt)

## Description
Re-resolve the ref at execution time (0.28 cut in progress); version/tag collision needs a user decision.

## Definition of done
- [ ] merge-base is-ancestor upstream-main main; fmt, clippy, workspace tests, crucible tests pass

## Falsifiers
- consequential transition actuated without fresh operator-supplied authority
- evidence claimed without a durable receipt binding the subject SHA
- standing promoted without observing the acceptance command's exit 0 against the exact subject
