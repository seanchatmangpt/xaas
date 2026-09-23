---
{
  "acceptance": [
    "0 open PRs; tree clean; format-recovery.yml absent"
  ],
  "authority_requirement": "NONE",
  "base_sha": "e90928d7b0687a959831553c4eacca3d75ca6c88",
  "dependencies": [
    {
      "type": "requiresReceipt",
      "upstream": "FERROPLAN-26922-01"
    }
  ],
  "description": "Commit docs/jira/v26.9.19; close #43/#44 as landed; delete superseded origin branches; drop format-recovery.yml.",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "falsifiers": [
    "evidence claimed without a durable receipt binding the subject SHA",
    "standing promoted without observing the acceptance command's exit 0 against the exact subject"
  ],
  "identity": "FERROPLAN-26922-4",
  "path_scope": [
    "docs/jira/** .github/workflows/**"
  ],
  "projections": [
    "jira",
    "receipt",
    "verification"
  ],
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.22-FERROPLAN-26922-4",
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
  "subject": "bookkeeping",
  "title": "Bookkeeping"
}
---

# FERROPLAN-26922-4: Bookkeeping

- **Standing**: UNKNOWN
- **Repository**: seanchatmangpt/ferroplan @ `e90928d`
- **Authority requirement**: NONE

- **Requires receipt of**: FERROPLAN-26922-01 (requiresReceipt)

## Description
Commit docs/jira/v26.9.19; close #43/#44 as landed; delete superseded origin branches; drop format-recovery.yml.

## Definition of done
- [ ] 0 open PRs; tree clean; format-recovery.yml absent

## Falsifiers
- evidence claimed without a durable receipt binding the subject SHA
- standing promoted without observing the acceptance command's exit 0 against the exact subject
