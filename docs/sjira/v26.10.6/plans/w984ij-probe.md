# W984ij — CapitalCensus unclaimed-family probe receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface (82f7f558 + new test file)
- Lane: W984ij, no commit, disjoint from all `M test/...` lanes (new file only:
  `test/xaas/capital_census/family_court_w984ij_test.exs`)

## Probe method

CamelCase grep of every `lib/xaas/ultracode/capital_census/**/*.ex` module
name against `test/`. Note: the domain lives under
`lib/xaas/ultracode/capital_census/` (plus `lib/xaas/generated/capital_census/facts.ex`),
not `lib/xaas/capital_census/` as the dispatch suggested.

## Per-module dispositions

| module (lib/xaas/ultracode/capital_census/) | disposition |
|---|---|
| experience.ex (170L) | covered — dedicated `experience_test.exs` |
| receipt.ex (344L) | covered — dedicated `receipt_test.exs` |
| route.ex (141L) | covered — dedicated `route_test.exs` |
| self_digest_law.ex (161L) | covered — self_digest_chicago/worker tests exercise classify/cluster/self_work_order |
| self_digest_run.ex (389L) | covered — self_digest_worker_test + mix xaas_self_digest test |
| episode.ex | indirectly-covered (create+read via chicago/worker tests); update + FrontierOutcome refusals were unexercised |
| experience_cluster.ex | indirectly-covered (create+read); update + `load :gaps` unexercised |
| gap.ex | indirectly-covered (create/read + one enum refusal); update/status transitions + `load :work_orders` unexercised |
| work_order.ex | indirectly-covered (create/read); update, `load :resolutions`, 2 of 3 enum refusals unexercised |
| resolution.ex (37L) | UNCOVERED — zero test refs to `CapitalCensus.Resolution` |
| types/*.ex (6 custom types) | indirectly-covered; only Gap `recurrence_class` refusal was exercised |
| generated/capital_census/facts.ex | covered — chicago test asserts Facts data |

## Court added

`test/xaas/capital_census/family_court_w984ij_test.exs` — 13 tests, real
sandboxed Postgres (`Xaas.DataCase` + SQL sandbox), real Ash actions, zero
mocks, mutation rationale comment per test. Pins: Resolution create/read/
update/refusal + `load :resolutions`; Gap hypothesis→admitted→refuted;
WorkOrder open→resolved; Episode error→handed_off + refusal;
ExperienceCluster episode_count update; cluster→gap→work_order relationship
loads; refusals for primitive_target / classification / status enums.

## Verification (executed)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ij mix test test/xaas/capital_census/family_court_w984ij_test.exs`
  → `13 tests, 13 passed, 0 failures` — exit 0
- Mock gate (`scan_mock_usage` on the new file) → `[]` — exit 0

## Cleanup

`_build-laneW984ij` (426M) removed after the run — see final note in receipt
below; lease law honored.

Standing: ALIVE (probe + court executed on the exact subject; no commit per
lane contract).
