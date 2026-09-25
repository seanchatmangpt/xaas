---
{
  "acceptance": [
    "cargo fmt --check and cargo check -p ferroplan --locked pass"
  ],
  "authority_requirement": "NONE",
  "base_sha": "e90928d7b0687a959831553c4eacca3d75ca6c88",
  "dependencies": [],
  "description": "Fix the 4 hunks from the ppcx merge.",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "falsifiers": [
    "evidence claimed without a durable receipt binding the subject SHA",
    "standing promoted without observing the acceptance command's exit 0 against the exact subject"
  ],
  "identity": "FERROPLAN-26922-1",
  "path_scope": [
    "crates/ferroplan/src/**"
  ],
  "projections": [
    "jira",
    "receipt",
    "verification"
  ],
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.22-FERROPLAN-26922-1",
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
  "subject": "rustfmt-policy-validation",
  "title": "rustfmt policy_validation.rs"
}
---

# FERROPLAN-26922-1: rustfmt policy_validation.rs

- **Standing**: UNKNOWN
- **Repository**: seanchatmangpt/ferroplan @ `e90928d`
- **Authority requirement**: NONE


## Description
Fix the 4 hunks from the ppcx merge.

## Definition of done
- [ ] cargo fmt --check and cargo check -p ferroplan --locked pass

## Falsifiers
- evidence claimed without a durable receipt binding the subject SHA
- standing promoted without observing the acceptance command's exit 0 against the exact subject
