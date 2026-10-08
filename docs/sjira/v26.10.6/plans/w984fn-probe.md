# W984fn — unclaimed-family probe receipt: lib/xaas/operations/

Lane: W984fn · Date: 2026-10-07 · Branch: feat/playwright-surface · NO commit (per dispatch).

Excluded families: Castle/Route-verb batch (W984fj owns
`RouteCastle*`, `CastleVerb*`, `ApprovalCastleVerbSchedule`, incl. its untracked
`test/xaas/operations/castle_verb_court_w984fj_test.exs`) and Incident lifecycle
(W650za; incl. `types/incident_*.ex`, `validations/incident_*.ex`).

## Method

CamelCase grep of every `lib/xaas/operations/**/*.ex` module name against
`test/` (W984er-class probe: name-level refs are necessary-not-sufficient, so
hit-listing modules were read and their branch-level wiring checked before any
COVERED disposition).

## Disposition table

| Module | Test refs | Disposition |
|---|---|---|
| ActuationIntent | 29 | COVERED (deep: 29 files) |
| ActuationReceipt | 35 | COVERED (deep) |
| Incident + types/validations | 29 | EXCLUDED (W650za) |
| RouteCastleDeploy/Run/Schedule/Sunset | 3–9 | EXCLUDED (W984fj) |
| CastleVerbInventoryComponents/Goals, ApprovalCastleVerbSchedule | 1–4 | EXCLUDED (W984fj) |
| CastleVerbFortune5Requirements | 1 | EXCLUDED (W984fj family) |
| ApprovalCausalAnatomy | 1 file | COVERED — controller court exercises admit, refuse, already-approved (counterfactual-stays-refused), missing-intent, non-map, and the HTTP metadata degrade branch (`metadata/1` both arms) |
| ApprovalK8sFaultRemediateSuggest | 3 | COVERED (controller + authority-scope courts) |
| AuditLogEntry | 9 | COVERED; file is sibling-modified in flight — not touched |
| AuthorityLedgerExport | 2 | COVERED (dedicated `authority_ledger_export_test.exs` + substitution court) |
| RefusalLedgerExport | 2 | COVERED (dedicated depth court) |
| AutofdePlanner* (6 modules) | 3–5 | COVERED (`autofde_planner_connector_depth_test.exs` exercises hotset/stats/candidate/catalog/match branches) |
| CapabilityLivenessReceipt/Regressions | 16/5 | COVERED — deepening court exercises INVALID_STATUS_VOCABULARY, ALIVE_WITHOUT_EXECUTION, W968c previous_status capture + forgery refusal + BLOCKED recapture |
| Changes.SetPreviousStatus | 0 name refs | COVERED indirectly (W968c tests in capability_liveness_deepening_test.exs exercise capture, non-forgeability, recapture) |
| Checks.ActorOrgMatches | 21 | COVERED |
| ProjectMeasure Census/Info/Receipt/Reactor/Measurement/Extension/SubjectSha | — | COVERED (project_measure_test.exs: verifier repository branch, SubjectSha 40-hex admission, census standing states, receipt tamper detection) |
| **ProjectMeasure.GitHubActions** | **0** | **UNCOVERED → courted** |
| **ProjectMeasure.Verifiers.ValidateConfiguration** | **0** | **UNCOVERED (only repository branch via extension) → courted 5 new branches** |

## Courts landed

`test/xaas/operations/family_court_w984fn_test.exs` — 11 tests, all real
modules, zero doubles:

* `GitHubActions.list_workflow_runs/4` fail-closed identity admission (5
  tests): nil / "owner" / "owner/" / "/name" each refuse
  `REFUSED[REPOSITORY_IDENTITY_INVALID]` before any HTTP; the three-segment
  split/2 contract pinned as distinct from identity refusal.
* `ValidateConfiguration` verifier branches (6 tests): absolute output_path,
  `..` traversal output_path, lowercase env name, nil env name (pinned at the
  Spark options-schema layer — the verifier's non-binary clause is
  defense-in-depth, unreachable via DSL), non-HTTPS api_url, api_url with
  embedded userinfo. Each test names its concrete mutation rationale.
  Real `Spark.Test.dsl_errors` compile-time admission over the production
  extension; unique per-test domain modules.

## Gates (real output)

```
MIX_BUILD_ROOT=_build-laneW984fn mix test test/xaas/operations/family_court_w984fn_test.exs
  → 11 passed, 0 failures (exit 0)
MIX_BUILD_ROOT=_build-laneW984fn mix run -e 'scan_mock_usage(["test","lib"])' → []
```

## Standing

PARTIAL_ALIVE: two genuinely unexercised state-bearing fail-closed surfaces
courted; every other module in the family classified with branch-level
evidence. HTTP-reachable branches of GitHubActions (pagination, count-drift,
truncation refusals) remain unexercised — they require a real GitHub surface
and are left typed-UNKNOWN. No commit; lane build root leased and removed at
integration per the fanout cleanup law.
