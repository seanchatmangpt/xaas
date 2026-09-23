---
{
  "acceptance": [
    "wasip1 clippy passes; worktree list at most 5"
  ],
  "authority_requirement": "NONE",
  "base_sha": "e90928d7b0687a959831553c4eacca3d75ca6c88",
  "dependencies": [
    {
      "type": "requiresReceipt",
      "upstream": "FERROPLAN-26922-01"
    }
  ],
  "description": "55 wasip1-clippy, 48 hygiene, 54 fond-unsafe-hddl (feeds 03); prune the 43 merged worktrees.",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "falsifiers": [
    "evidence claimed without a durable receipt binding the subject SHA",
    "standing promoted without observing the acceptance command's exit 0 against the exact subject"
  ],
  "identity": "FERROPLAN-26922-7",
  "path_scope": [
    "crates/**"
  ],
  "projections": [
    "jira",
    "receipt",
    "verification"
  ],
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.22-FERROPLAN-26922-7",
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
  "subject": "respawn-tickets",
  "title": "Finish or retire respawn tickets fond-htn-47..56"
}
---

# FERROPLAN-26922-7: Finish or retire respawn tickets fond-htn-47..56

- **Standing**: UNKNOWN
- **Repository**: seanchatmangpt/ferroplan @ `e90928d`
- **Authority requirement**: NONE

- **Requires receipt of**: FERROPLAN-26922-01 (requiresReceipt)

## Description
55 wasip1-clippy, 48 hygiene, 54 fond-unsafe-hddl (feeds 03); prune the 43 merged worktrees.

## Definition of done
- [ ] wasip1 clippy passes; worktree list at most 5

## Falsifiers
- evidence claimed without a durable receipt binding the subject SHA
- standing promoted without observing the acceptance command's exit 0 against the exact subject
