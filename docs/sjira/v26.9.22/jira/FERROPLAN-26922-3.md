---
{
  "acceptance": [
    "sa2a_goal_set_ruling and planning_runtime tests pass; dated standing row in the divergence ticket"
  ],
  "authority_requirement": "OPERATOR_DECISION_REQUIRED",
  "base_sha": "e90928d7b0687a959831553c4eacca3d75ca6c88",
  "dependencies": [
    {
      "type": "requiresReceipt",
      "upstream": "FERROPLAN-26922-01"
    }
  ],
  "description": "Vendor autofde-lab's sa2a-v26.9.17 domain/problem (no :goal), run fresh at HEAD, record ruling (a) or implement flag-gated (b).",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "falsifiers": [
    "consequential transition actuated without fresh operator-supplied authority",
    "evidence claimed without a durable receipt binding the subject SHA",
    "standing promoted without observing the acceptance command's exit 0 against the exact subject"
  ],
  "identity": "FERROPLAN-26922-3",
  "path_scope": [
    "docs/jira/v26.9.17/** crates/**"
  ],
  "projections": [
    "jira",
    "receipt",
    "verification"
  ],
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.22-FERROPLAN-26922-3",
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
  "subject": "fond-htn-67-ruling",
  "title": "Rule on fond-htn-67"
}
---

# FERROPLAN-26922-3: Rule on fond-htn-67

- **Standing**: UNKNOWN
- **Repository**: seanchatmangpt/ferroplan @ `e90928d`
- **Authority requirement**: OPERATOR_DECISION_REQUIRED

- **Requires receipt of**: FERROPLAN-26922-01 (requiresReceipt)

## Description
Vendor autofde-lab's sa2a-v26.9.17 domain/problem (no :goal), run fresh at HEAD, record ruling (a) or implement flag-gated (b).

## Definition of done
- [ ] sa2a_goal_set_ruling and planning_runtime tests pass; dated standing row in the divergence ticket

## Falsifiers
- consequential transition actuated without fresh operator-supplied authority
- evidence claimed without a durable receipt binding the subject SHA
- standing promoted without observing the acceptance command's exit 0 against the exact subject
