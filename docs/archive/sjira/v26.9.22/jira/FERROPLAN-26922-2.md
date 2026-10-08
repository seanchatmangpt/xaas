---
{
  "acceptance": [
    "CI main workflow success; plugins/chatman-ecosystem pytest passes"
  ],
  "authority_requirement": "NONE",
  "base_sha": "e90928d7b0687a959831553c4eacca3d75ca6c88",
  "dependencies": [
    {
      "type": "requiresReceipt",
      "upstream": "FERROPLAN-26922-01"
    }
  ],
  "description": "FERROPLAN_ORACLE_DIR/FERROPLAN_CORPUS_DIR defaulting to ~/.cache/ferroplan so the ignored tests run or skip by name; fix the chatman-ecosystem projection-law job.",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "falsifiers": [
    "evidence claimed without a durable receipt binding the subject SHA",
    "standing promoted without observing the acceptance command's exit 0 against the exact subject"
  ],
  "identity": "FERROPLAN-26922-2",
  "path_scope": [
    ".github/workflows/** crates/**"
  ],
  "projections": [
    "jira",
    "receipt",
    "verification"
  ],
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.22-FERROPLAN-26922-2",
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
  "subject": "durable-oracle-corpus",
  "title": "A deep lane that can pass"
}
---

# FERROPLAN-26922-2: A deep lane that can pass

- **Standing**: UNKNOWN
- **Repository**: seanchatmangpt/ferroplan @ `e90928d`
- **Authority requirement**: NONE

- **Requires receipt of**: FERROPLAN-26922-01 (requiresReceipt)

## Description
FERROPLAN_ORACLE_DIR/FERROPLAN_CORPUS_DIR defaulting to ~/.cache/ferroplan so the ignored tests run or skip by name; fix the chatman-ecosystem projection-law job.

## Definition of done
- [ ] CI main workflow success; plugins/chatman-ecosystem pytest passes

## Falsifiers
- evidence claimed without a durable receipt binding the subject SHA
- standing promoted without observing the acceptance command's exit 0 against the exact subject
