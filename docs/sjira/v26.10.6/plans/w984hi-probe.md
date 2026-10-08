# W984hi — unclaimed-family probe: `lib/xaas/ultracode/` remainder

Lane W984hi, branch `feat/playwright-surface`, canonical checkout `/Users/sac/xaas`.
2026-10-07. No commit (per dispatch).

## Scope exclusion (lane disjointness)

- `provider_mesh/**` — owned by W984dz / W650h21 (their lane tests untracked in
  `test/xaas/ultracode/provider_mesh/`).
- `validations/**` — courted by W984ds/W984ek's epoch subject.
- `semantic_drive*`, `semantic_wave_trigger*` — tests exist
  (`test/xaas/ultracode/semantic_drive*`, `semantic_wave_trigger` hits).

## Method

CamelCase module-name grep of each non-excluded module against `test/`, then
alias-aware re-check (`Law`, `SelfDigest` aliases) and call-site trace into
`lib/` DSL wiring (changes run via `run.ex` actions, not by name).

## Dispositions

| module | hits | disposition |
|---|---|---|
| `changes/extend_cycle_budget.ex` | 0 | **indirect via `:resume_frontier`**, never-shrink arm unexercised → courted |
| `changes/revoke_live_leases.ex` | 0 | **indirect via `Run.:stop`**; live arm covered (engine_test stop court); expired arm unexercised → courted |
| `changes/set_terminal_at.ex` | 0 | indirect via `:transition_state`/`:stop`; suspend/resume_frontier non-terminal path unwalked → courted |
| `changes/set_suspended_at.ex` | 0 | indirectly covered (`closure_controller_test` asserts `suspended_at != nil`) |
| `changes/set_frontier_recorded_at.ex` | 0 | indirectly covered (`:record_frontier` via `ClosureController.record` tests) |
| `changes/create_first_epoch.ex` | 3 | indirectly covered (`Run.:start` tests) |
| `capital_census/self_digest_law.ex` | 0 | covered — aliased `Law` in `self_digest_chicago_test.exs` |
| `capital_census/self_digest_run.ex` | 0 | covered — aliased `SelfDigest` in `self_digest_worker_test.exs`, `oban_depth_w984cn_test.exs` |
| `capital_census/types/*` (6 enums) | 0 | non-state-bearing enum types, referenced via resource constraints; indirectly covered via `self_digest*` and `work_order` tests |
| `receipt.ex`, `capital_census/receipt.ex`, `capability_resolver/receipt.ex` | 157 | covered |
| `run.ex` | 211 | covered |
| everything else (audit, epoch, engine, reactor, lease, wave_loop, verifier, dispatch, semantic_*, closure_controller, frontier, etc.) | 1–73 | covered / indirectly covered by the existing `test/xaas/ultracode/*` suite (module-name or alias hits plus action-level call-site trace) |

## Courts added

`test/xaas/ultracode/remainder_court_w984hi_test.exs` — 3 tests, zero doubles,
mutation rationale per test:

1. `resume_frontier` never shrinks a larger `max_cycles`
   (`Changes.ExtendCycleBudget` max arm — existing test's `>=` admits a
   shrinking mutant) + `SetTerminalAt` non-terminal arm (terminal_at stays nil
   through suspend/resume_frontier).
2. `resume_frontier` grows from below, exact bound (`max(1, 0+3) == 3`).
3. `Run.:stop` skips an EXPIRED lease (epoch stays `:running`, no receipt)
   while revoking the LIVE lease on the same run (epoch `:failed`, one
   `:refused`/`run_stopped` receipt) — `RevokeLiveLeases` expired arm had no
   witness anywhere in `test/`.

## Gates (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984hi \
  mix test test/xaas/ultracode/remainder_court_w984hi_test.exs
→ exit 0, "3 passed"
mock gate scan_mock_usage(["test","lib"]) → []
rm -rf _build-laneW984hi → removed (no denial)
```

## Transport notes

- First compile hit a SyntaxError in `lib/mix/tasks/xaas.release_audit.ex`
  (another lane's in-flight 15-line diff). Compiles clean as of re-run; no fix
  applied by this lane. Per compile-freeze SLA this is disclosed, owned by the
  W984gv-labeled diff in that file.
- Lane-local fixes during court construction: `require Ash.Query`,
  Receipt `:read` (no `:read_unscoped` on Receipt), tenant-required Epoch
  `:lease` changeset (tenant passed per durable_close_court_test pattern).
