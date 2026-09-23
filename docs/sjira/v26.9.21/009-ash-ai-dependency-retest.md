---
{
  "identity": "SJ-009",
  "title": "Retest the ash_ai dependency probe against current deps",
  "description": "The probe branch's tip is preserved at tag archive/probe-ash-ai-dependency-retest-fa744ec (superseded-merged). Re-run the retest on current main: add ash_ai in a worktree, `mix deps.get && mix compile && mix test`, record whether the earlier incompatibility persists.",
  "subject": "ash-ai-dependency-retest",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "ALIVE",
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

- **Standing**: ALIVE (verdict COMPATIBLE)

## Status
ALIVE — verdict COMPATIBLE. Resolved by commit `4f6ef4fd` (receipt
`docs/sjira/v26.9.21/receipts/SJ-009.md`) and reconfirmed this session
(2026-09-22, same tree, base_sha `01aa6fbf0b8fc5430f6a48bc4ccd24e11d4ac30a`,
`git diff 01aa6fbf -- mix.exs mix.lock` empty):

| # | Command | Exit | Observed |
|---|---|---|---|
| 1 | `mix deps.get` | 0 | `All dependencies have been fetched`; ash_ai 1.0.3 resolved |
| 2 | `mix compile` | 0 | `Compiling 478 files (.ex)`, `Generated xaas app` |
| 3 | `MIX_TEST_PARTITION=_sj009rerun mix test` | 0 | `1346 tests, 0 failures (71 excluded)`, `Finished in 74.8 seconds` |

ash_ai 1.0.3 / req_llm 1.20.0 / finch 0.23.0 / req 0.7.4 resolve and run together on current main;
the earlier probe-branch finch/req_llm incompatibility (tag
`archive/probe-ash-ai-dependency-retest-fa744ec`) does not reproduce.
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

## Description
The probe branch's tip is preserved at tag archive/probe-ash-ai-dependency-retest-fa744ec (superseded-merged). Re-run the retest on current main: add ash_ai in a worktree, `mix deps.get && mix compile && mix test`, record whether the earlier incompatibility persists.

## Evidence
- tag archive/probe-ash-ai-dependency-retest-fa744ec on origin
- `docs/sjira/v26.9.21/receipts/SJ-009.md` (full receipt: commands, exits, courts, SA2A replay)
- `docs/sjira/v26.9.21/receipts/SJ-009.verification-manifest.json`
- `docs/sjira/v26.9.21/receipts/sa2a-replay-SJ-009.json`
- this session's rerun: `deps.get` exit 0, `compile` exit 0 (478 files), `mix test` exit 0
  (1346 tests, 0 failures, 71 excluded), same tree as the receipted commit

## Definition of done
- [x] a receipt states COMPATIBLE or the exact failing dependency edge — COMPATIBLE,
      `docs/sjira/v26.9.21/receipts/SJ-009.md`

Runnable check:

```sh
cd <worktree> && mix deps.get && mix compile && mix test
```

## Falsifiers
- result reported without running deps.get + compile + test
