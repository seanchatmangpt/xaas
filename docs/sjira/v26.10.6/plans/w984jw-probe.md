# W984jw — project-measure core probe receipt

Lane: W984jw · subject: `/Users/sac/xaas` @ branch `feat/playwright-surface`,
HEAD `145b5659` (no commits made; test file only, uncommitted by design).
Scope: `lib/xaas/operations/project_measure/` core (Census + Receipt +
Reactor/Measurement surfaces). W984fn already courts the Spark/verifier layer;
W984dp4 courts `github_actions.ex` transport — both left alone.

## Court file

`test/xaas/operations/measure_core_court_w984jw_test.exs` — 27 tests,
real collaborators (real Census/Receipt modules, real temp files for replay),
zero mocks. Mutation rationale inline per test.

## Dispositions

| branch / surface | disposition |
|---|---|
| `build/5` catch-all `PROJECT_MEASURE_INPUT_INVALID` (non-DateTime window, non-list rows) | COVERED (new) — was unexercised |
| `validate_config` missing-key + blank-binary branches `PROJECT_MEASURE_CONFIG_INCOMPLETE` (all 5 keys) | COVERED (new) |
| census-layer `REPOSITORY_IDENTITY_INVALID` at build time (distinct from W984fn Spark-verifier layer) | COVERED (new) |
| `row_time` malformed + non-binary clauses `CI_RUN_TIMESTAMP_INVALID` (with detail) | COVERED (new) |
| `row_head_sha` missing/empty `CI_RUN_SUBJECT_IDENTITY_MISSING` | COVERED (new) |
| identity fallback `node:` clause + node-keyed dedup collapse/conflict | COVERED (new) |
| `CI_RUN_IDENTITY_MISSING` (no id, no node_id) | COVERED (new) |
| `evidence_state == "COMPLETED_NO_FAILURE_LIKE"` | COVERED (new) — never asserted by prior courts |
| `@failure_like` full set (action_required/cancelled/timed_out/startup_failure) | COVERED (new) — prior court only used `failure` |
| `conclusion_counts` nil→"none" bucketing | COVERED (new) |
| `value/nullable_value` sparse-row + non-binary defaults | COVERED (new) |
| `Receipt.verify/1` malformed/receipt-less heads | COVERED (new) |
| `Receipt.canonical_json` atom-key stringification, lists, scalars | COVERED (new) |
| `Census.replay_file!` :ok path + tampered REFUSED + malformed JSON | COVERED (new, real files) |
| outside-window vs off-subject tally separation + cond clause order | COVERED (new) |
| admit_rows order preservation (Enum.reverse) + identity sort | COVERED (new) |
| `github_actions.ex`, `validate_configuration` | COVERED — W984fn/W984dp4, not duplicated |
| Spark verifier/repository-identity DSL layer | COVERED — W984fn |
| `Census.observe!/2` HTTP path | NOT COURTED (network transport; W984dp4 owns wire coverage) |
| `Measurement` Ash resource actions | INDIRECTLY COVERED — existing `project_measure_test.exs` |

## Witnessed finding (contract, not defect)

`evidence_state` keys on run `status`, not conclusion presence: a run with
`status="completed"` and `conclusion=nil` classifies
`COMPLETED_NO_FAILURE_LIKE` and counts in `conclusion_counts` under `"none"`
rather than PENDING. Asserted as witnessed contract in the court
(`w984jw` line ~254); flag to owner if PENDING was intended.

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984jw
  mix test test/xaas/operations/measure_core_court_w984jw_test.exs`
  → `Result: 27 passed`, exit 0 (after 2 first-run failures fixed: Map.delete/1
  arity bug in test, and the evidence_state nil-conclusion contract above).
- Mock gate: `scan_mock_usage(["test","lib"])` → `[]`.
- Adjacent regression `project_measure_test.exs + family_court_w984fn_test.exs`
  → `Result: 25 passed`.
- PromEx/Grafana upload warnings during gates are pre-existing ambient noise.

## Cleanup

`_build-laneW984jw` lane build root: deleted after gates (see task log).
No commit made, per lane contract.
