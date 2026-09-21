---
{
  "identity": "SJ-009",
  "title": "Retest the ash_ai dependency probe against current deps",
  "description": "The probe branch's tip is preserved at tag archive/probe-ash-ai-dependency-retest-fa744ec (superseded-merged). Re-run the retest on current main: add ash_ai in a worktree, `mix deps.get && mix compile && mix test`, record whether the earlier incompatibility persists.",
  "subject": "ash-ai-dependency-retest",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-009",
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
    "a receipt states COMPATIBLE or the exact failing dependency edge"
  ],
  "falsifiers": [
    "result reported without running deps.get + compile + test"
  ],
  "projections": [
    "jira",
    "verification",
    "receipt"
  ],
  "dependencies": [],
  "authority_requirement": "NONE",
  "path_scope": [
    "mix.exs",
    "mix.lock"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-009: Retest the ash_ai dependency probe against current deps

- **Standing**: UNKNOWN
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

## Description
The probe branch's tip is preserved at tag archive/probe-ash-ai-dependency-retest-fa744ec (superseded-merged). Re-run the retest on current main: add ash_ai in a worktree, `mix deps.get && mix compile && mix test`, record whether the earlier incompatibility persists.

## Evidence
- tag archive/probe-ash-ai-dependency-retest-fa744ec on origin

## Definition of done
- [ ] a receipt states COMPATIBLE or the exact failing dependency edge

Runnable check:

```sh
cd <worktree> && mix deps.get && mix compile && mix test
```

## Falsifiers
- result reported without running deps.get + compile + test
