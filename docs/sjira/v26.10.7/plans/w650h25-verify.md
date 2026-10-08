# W650h25 — Landing-Verification Sweep Receipt

Lane: W650h25, v26.10.7 fleet seal. Subject: HEAD `78127188` (branch `feat/playwright-surface`), 2026-10-07.
Scope: read-only verification; no commits, no fresh-root compile. One batched `mix test` run under the
pinned toolchain (asdf shims, `MIX_ENV=test`).

## Command

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test <11 files listed below>
```

Result: `55 passed` in 1.2s, exit 0. (One pre-existing type warning in
`test/xaas/ultracode/process_group_court_test.exs:128` — non-fatal, test passes.)

## Tracked / green table

| # | File | Lane / SHA ref | Tracked | Green |
|---|------|----------------|---------|-------|
| 1 | test/xaas/conference/registration_status_transition_court_w650y4_test.exs | W650h16 bdc6d823 | Y | Y (in batch, 55-pass run) |
| 2 | test/xaas/conference/sponsor_track_lifecycle_court_w984dn_test.exs | W984dq4 9ec12305 | Y | Y |
| 3 | test/xaas/governance/w984dr_environment_court_test.exs | W650h16 | Y | Y |
| 4 | test/xaas/governance/w984dr_pentest_finding_status_court_test.exs | W650h16 | Y | Y |
| 5 | test/xaas/operations/approval_castle_verb_schedule_authority_test.exs | W984dq4 bcf1371d | Y | Y |
| 6 | test/xaas/ultracode/process_group_court_test.exs | W650h6 9ec12305 | Y | Y |
| 7 | test/xaas/research_runtime/closure/coordinator_test.exs | W650h6 | Y | Y |
| 8 | test/xaas/governance/w984cy4_override_decision_court_test.exs | W650h6 | Y | Y |
| 9 | test/xaas/sjira/w984dp3_atlassian_cursor_court_test.exs | W984dp3 9ec12305 | Y | Y |
| 10 | test/xaas/cs2/fleet_contract_test.exs | W650h18 dc86fb76 | Y | Y |
| 11 | test/xaas/cs2/generated_fleet_contract_test.exs | W650h18 dc86fb76 | Y | Y |

## Standing

ALIVE — 11/11 tracked at HEAD, 11/11 green in a single batched run (55 tests, 0 failures, exit 0).
Green attribution is per-batch (aggregate run covers all files); no per-file isolation runs performed,
per lane scope ("green ×1 in one batch").
