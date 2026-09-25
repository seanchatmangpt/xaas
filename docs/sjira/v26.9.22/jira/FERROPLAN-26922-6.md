---
{
  "acceptance": [
    "the checker exits 0 on docs/jira and non-zero on a mutated copy"
  ],
  "authority_requirement": "NONE",
  "base_sha": "e90928d7b0687a959831553c4eacca3d75ca6c88",
  "dependencies": [
    {
      "type": "requiresReceipt",
      "upstream": "FERROPLAN-26922-04"
    }
  ],
  "description": "verify_ticket_standing.py fails when frontmatter disagrees with the last History row (49 contradictions).",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "falsifiers": [
    "evidence claimed without a durable receipt binding the subject SHA",
    "standing promoted without observing the acceptance command's exit 0 against the exact subject"
  ],
  "identity": "FERROPLAN-26922-6",
  "path_scope": [
    "scripts/** docs/jira/**"
  ],
  "projections": [
    "jira",
    "receipt",
    "verification"
  ],
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.22-FERROPLAN-26922-6",
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
  "subject": "standing-guard",
  "title": "Standing guard for ticket frontmatter"
}
---

# FERROPLAN-26922-6: Standing guard for ticket frontmatter

- **Standing**: UNKNOWN
- **Repository**: seanchatmangpt/ferroplan @ `e90928d`
- **Authority requirement**: NONE

- **Requires receipt of**: FERROPLAN-26922-04 (requiresReceipt)

## Description
verify_ticket_standing.py fails when frontmatter disagrees with the last History row (49 contradictions).

## Definition of done
- [ ] the checker exits 0 on docs/jira and non-zero on a mutated copy

## Falsifiers
- evidence claimed without a durable receipt binding the subject SHA
- standing promoted without observing the acceptance command's exit 0 against the exact subject
