---
{
  "identity": "SJ-008",
  "title": "Close the four open gymact backlog tickets",
  "description": "docs/2026-08-13-gymact-jira-backlog.md: GYMACT-1 (dev_portfolio not registered) and GYMACT-2 (false docstring) marked In Progress; GYMACT-3 (CLAUDE.md cites missing STATUS.md / ecosystem-standing.md) and GYMACT-4 (8 pytest failures, unreproduced) Open. Re-verify each with a real command, fix what still reproduces, update the backlog Status.",
  "subject": "gymact-open-backlog",
  "repository": "seanchatmangpt/gymact",
  "base_sha": "4ab72e685302aa591f65fecad0ec73129ecd3589",
  "standing": "PARTIAL_ALIVE",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-008",
  "required_courts": [
    "compile",
    "tests",
    "chicago_no_mocks"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "each ticket's Definition of done command passes",
    "backlog Status fields updated to Done/Not-reproducible with evidence"
  ],
  "falsifiers": [
    "GYMACT-4 closed without a repeated full pytest run"
  ],
  "projections": [
    "jira",
    "verification",
    "receipt"
  ],
  "dependencies": [],
  "authority_requirement": "NONE",
  "path_scope": [
    "src/gymact/gyms/**",
    "docs/**",
    "CLAUDE.md"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-008: Close the four open gymact backlog tickets

- **Standing**: PARTIAL_ALIVE

## Status
PARTIAL_ALIVE
- **Repository**: seanchatmangpt/gymact @ `4ab72e6`

## Description
docs/2026-08-13-gymact-jira-backlog.md: GYMACT-1 (dev_portfolio not registered) and GYMACT-2 (false docstring) marked In Progress; GYMACT-3 (CLAUDE.md cites missing STATUS.md / ecosystem-standing.md) and GYMACT-4 (8 pytest failures, unreproduced) Open. Re-verify each with a real command, fix what still reproduces, update the backlog Status.

## Evidence
- 4 tickets in the backlog file (verified by grep 2026-09-21)

## Definition of done
- [ ] each ticket's Definition of done command passes
- [ ] backlog Status fields updated to Done/Not-reproducible with evidence

Runnable check:

```sh
cd ~/gymact && python -m pytest -q
```

## Falsifiers
- GYMACT-4 closed without a repeated full pytest run
