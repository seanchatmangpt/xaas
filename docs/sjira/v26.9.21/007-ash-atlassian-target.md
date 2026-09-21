---
{
  "identity": "SJ-007",
  "title": "Scope the ash_atlassian migration target",
  "description": "The whitepaper's Atlassian -> ash_atlassian migration has no target: ~/ash_atlassian does not exist and ~/atlassian is an empty stub. BLOCKED:NO_TARGET_PACKAGE. Deliverable is a scoped ARD (resources, ontology source, generator route via ggen-marketplace) so the blocker becomes a buildable order.",
  "subject": "ash-atlassian-target",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "BLOCKED",
  "evidence_ceiling": "CONSTRUCTED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-007",
  "required_courts": [
    "tests"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "an ARD under docs/sjira/v26.9.21/ names the ontology source and pack route",
    "a follow-up work order set is emitted as new SJ files"
  ],
  "falsifiers": [
    "ARD proposes hand-written resources where a pack could generate them"
  ],
  "projections": [
    "jira",
    "ard",
    "prd",
    "hddl"
  ],
  "dependencies": [],
  "authority_requirement": "NONE",
  "path_scope": [
    "docs/sjira/**"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-007: Scope the ash_atlassian migration target

- **Standing**: BLOCKED
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

## Description
The whitepaper's Atlassian -> ash_atlassian migration has no target: ~/ash_atlassian does not exist and ~/atlassian is an empty stub. BLOCKED:NO_TARGET_PACKAGE. Deliverable is a scoped ARD (resources, ontology source, generator route via ggen-marketplace) so the blocker becomes a buildable order.

## Evidence
- `ls ~/ash_atlassian` -> No such file or directory
- `ls ~/atlassian` -> one stub entry (verified 2026-09-21)

## Definition of done
- [ ] an ARD under docs/sjira/v26.9.21/ names the ontology source and pack route
- [ ] a follow-up work order set is emitted as new SJ files

Runnable check:

```sh
test -f docs/sjira/v26.9.21/ash-atlassian-ard.md
```

## Falsifiers
- ARD proposes hand-written resources where a pack could generate them
