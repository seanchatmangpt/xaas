---
{
  "identity": "SJ-006",
  "title": "Fold SA2A / Semantic Jira / zcode findings into autofde-lab ecosystem-standing",
  "description": "docs/ecosystem-standing.md names none of SA2A, XaaS, zcode, ggen_igniter, Semantic Jira. Add rows using the standing vocabulary, each with a reproducible command (sa2a bridge: `pytest tests/beam/` = 4 passed; SJ-001/SJ-002 standings from this directory).",
  "subject": "ecosystem-standing-foldin",
  "repository": "seanchatmangpt/autofde-lab",
  "base_sha": "2f4825a232bfea543764d13f3b75fcb0ff33da1f",
  "standing": "PARTIAL_ALIVE",
  "evidence_ceiling": "OBSERVED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-006",
  "required_courts": [
    "tests"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "ecosystem-standing.md has a row per system with standing + command",
    "no row is ALIVE without an observed run"
  ],
  "falsifiers": [
    "a row claims ALIVE with no command"
  ],
  "projections": [
    "jira",
    "executive",
    "receipt"
  ],
  "dependencies": [
    {
      "upstream": "SJ-001",
      "type": "requiresReceipt"
    },
    {
      "upstream": "SJ-002",
      "type": "requiresReceipt"
    }
  ],
  "authority_requirement": "NONE",
  "path_scope": [
    "docs/ecosystem-standing.md"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-006: Fold SA2A / Semantic Jira / zcode findings into autofde-lab ecosystem-standing

- **Standing**: PARTIAL_ALIVE

## Status
PARTIAL_ALIVE
- **Repository**: seanchatmangpt/autofde-lab @ `2f4825a`

## Description
docs/ecosystem-standing.md names none of SA2A, XaaS, zcode, ggen_igniter, Semantic Jira. Add rows using the standing vocabulary, each with a reproducible command (sa2a bridge: `pytest tests/beam/` = 4 passed; SJ-001/SJ-002 standings from this directory).

- autofde-lab/docs/2026-09-21-zero-human-factory-standing.md

## Definition of done
- [ ] ecosystem-standing.md has a row per system with standing + command
- [ ] no row is ALIVE without an observed run

Runnable check:

```sh
cd ~/autofde-lab && .venv/bin/python -m pytest tests/beam/ -v
```

## Falsifiers
- a row claims ALIVE with no command
