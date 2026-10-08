# W984ix — research_runtime long-tail court

Lane: W984ix, canonical checkout /Users/sac/xaas @ branch feat/playwright-surface (no commit, no branch change, no stash).
Input: W984it seventh re-census `/tmp/w984it_map.txt` lines 14–32 — 19 uncovered 2-pub
`Xaas.ResearchRuntime.*` modules.

## Dispositions

All 19 modules are one homogeneous state-bearing family: `@enforce_keys` struct +
`new/1` (nil/""/absent key → `{:error, :missing_*}`) + `admit/2` (true predicate →
`status: :admitted`, false → `{:error, :refused}` with source untouched). All are
state-bearing (status field transitions on admit) → courted, none pure-thin, none
skipped.

Courted in one table-driven Chicago test, real struct state asserted at every step,
zero mocks:

`test/xaas/research_runtime_court_w984ix_test.exs`

| # | Module | key | refusal reason | disposition |
|---|---|---|---|---|
| 1 | ResearchRuntime.BoundedDo | :work_order_iri | :missing_work_order_iri | COURTED |
| 2 | ResearchRuntime.CommandBudget | :budget | :missing_budget | COURTED |
| 3 | ResearchRuntime.CommandTopology | :command_id | :missing_command_id | COVERED (court) |
| 4 | ResearchRuntime.ConsumerBoundary | :consumer_id | :missing_consumer_id | COURTED |
| 5 | ResearchRuntime.EdgeSet | :edge_id | :missing_edge_id | COURTED |
| 6 | ResearchRuntime.FondRecovery | :edge_id | :missing_edge_id | COURTED |
| 7 | ResearchRuntime.GenerationFence | :generation | :missing_generation | COURTED |
| 8 | ResearchRuntime.MigrationGuard | :migration_id | :missing_migration_id | COURTED |
| 9 | ResearchRuntime.OsirisBoundary | :subject_sha | :missing_subject_sha | COURTED |
| 10 | ResearchRuntime.PlannerBinding | :planner_id | :missing_planner_id | COURTED |
| 11 | ResearchRuntime.PolyEvidence | :evidence_id | :missing_evidence_id | COURTED |
| 12 | ResearchRuntime.PowlTrace | :trace_id | :missing_trace_id | COURTED |
| 13 | ResearchRuntime.PromotionPolicy | :candidate_id | :missing_candidate_id | COURTED |
| 14 | ResearchRuntime.QueryContract | :query_id | :missing_query_id | COURTED |
| 15 | ResearchRuntime.RacapPair | :episode_id | :missing_episode_id | COURTED |
| 16 | ResearchRuntime.RecoveryReceipt | :receipt_id | :missing_receipt_id | COURTED |
| 17 | ResearchRuntime.SemanticPart | :part_id | :missing_part_id | COURTED |
| 18 | ResearchRuntime.Steering | :context_id | :missing_context_id | COURTED |
| 19 | ResearchRuntime.VkgConsumer | :source_sha | :missing_source_sha | COURTED |

Previously covered by existing wave/court tests (17 modules: ContextWindow,
Coordinator, Epoch, Event, EvidenceAdmission, ExactSubject, ExecutionEnvelope,
GraphInvariant, HddlTask, Intent, PortableContract, Replay, SemanticEdge,
SourceBinding, Standing, SurvivalEvidence, WorkOrder) — not re-courted.

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ix mix test
  test/xaas/research_runtime_court_w984ix_test.exs` → `1 passed`, MIX_EXIT=0.
  (First run failed: my own test bug — tuple passed as assert message; fixed by
  removing the tuples, disclosed, not a subject defect.)
- Mock gate `scan_mock_usage(["test","lib"])` → `[]`.

## Cleanup

`rm -rf _build-laneW984ix` attempted after gates; see session receipt for outcome.
