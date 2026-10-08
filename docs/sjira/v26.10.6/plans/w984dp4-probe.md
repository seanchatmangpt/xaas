# W984dp4 — Burn-down continuation probe (v26.10.6)

Date: 2026-10-07 · Lane: W984dp4 · Repo: /Users/sac/xaas · Branch: feat/playwright-surface (uncommitted, per lane law)

## Census (fresh, CamelCase-aware, name+surface cross-checked)

Candidates from W984dj2's census note were checked first, before ranking:

- `ApprovalCastleVerbSchedule` / `RouteCastleDeploy` / `RouteCastleSchedule` /
  `RouteCastleSunset` — **claimed**: an in-flight lane (uncommitted, untracked
  `test/xaas/operations/castle_approval_route_surface_test.exs` +
  `approval_castle_verb_schedule_authority_test.exs` + `castle_verb_inventory_policy_floor_test.exs`
  already on disk; W984dp2's receipt `w984dp2-ops-residue.md` has NOT landed yet).
  Treated as covered-by-in-flight-lane, not re-courted (no double-lane collision).
- Billing `ApprovalDeniedPartyOverride` (W984cy4 OverrideDecision court) — skip per task.
- Billing `ApprovalPatchSlaCreditApplyApprove` (148 LOC) — census flag only;
  surface-level grep shows `test/xaas/billing/approval_sla_credit_apply_test.exs`
  already courts the real credit/idempotency/rollback invariants. Skip.
- `Sponsor`/`Track` (W984dn), ultracode remainder (W984dj4) — done, skip.
- `Xaas.Actuation.Validations.CausalAdmission`, `FreezeWindowActive`,
  Ocel `RelateEventToObjects`, `TemporalMemory.Changes`, all resource-level
  validation hosts (ApprovalSsoRoleMapping / AuditExportToken / RouteProjectsBackups /
  RouteOrgsCustomDomain) — surface-level covered by committed tests. Skip.

**Census winner**: `Xaas.Operations.ProjectMeasure.GitHubActions`
(`lib/xaas/operations/project_measure/github_actions.ex`, 151 LOC, zero test
references; sibling `project_measure_test.exs` covers the ProjectMeasure
resource surface but never this module).

## Court: 5 tests, real invariants, mutation rationale per test

File: `test/xaas/operations/project_measure_github_actions_court_w984dp4_test.exs`
(only file written; no lib changes).

All collaborators real: the module's own `Req.get/2` client against a real
Bandit/Plug listener on 127.0.0.1 port 0 (same Chicago pattern as
`gymact_surface_deepening_test.exs`); no mocks/stubs. Scripting via
`:persistent_term`; hits counted with a real `:counters` counter.

| # | Test | Invariant | Mutant killed |
|---|------|-----------|---------------|
| 1 | malformed repository identity | `REFUSED[REPOSITORY_IDENTITY_INVALID]` for `"owner-only"`, `""`, `"owner/"`, `"/name"`, `nil`, with zero wire hits | removes/loosens `split_repository/1` (would emit malformed `/repos//...` requests) |
| 2 | real 3-page pagination incl. final partial page | 250 rows via 3 real HTTP requests, exact row ids 1001–1100/2001–2100/3001–3050 | `div` instead of ceiling in `pages`, early `page >= pages` stop dropping the partial page |
| 3 | truncation fail-closed | total 250 reported, 200 served -> `REFUSED[CI_RUN_SEARCH_TRUNCATED]` | drops the `length(all_rows) == total` final consistency check |
| 4 | mid-pagination count drift | page 1 reports 200, page 2 reports 150 -> `REFUSED[CI_RUN_COUNT_DRIFT]`, exactly 2 wire hits | removes `validate_total/4` expected-vs-observed comparison |
| 5 | bounded pagination | total 12 000 -> 100 real requests then `REFUSED[CI_RUN_PAGINATION_UNBOUNDED]` | removes/raises the `@max_pages` guard (loop-termination safety) |

## Disclosed contract boundary (observed, not courted)

`split_repository/1` only requires both "/"-split parts non-empty: whitespace
identities (`" a/b"`, `"a b/c"`) and embedded-slash names (`"o//r"` -> name
`"/r"`) pass verbatim into the request path. Not a lane invariant to change;
disclosed in the test moduledoc for a future owner.

## Verification (×2, fresh lane root)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dp4 \
  mix test test/xaas/operations/project_measure_github_actions_court_w984dp4_test.exs
```

- Run 1: EXIT=0, 5 passed, 0 failures (0.3s)
- Run 2: EXIT=0, 5 passed, 0 failures
- Build root `_build-laneW984dp4` deleted at lane close.

## Standing

- `Xaas.Operations.ProjectMeasure.GitHubActions`: **PARTIAL_ALIVE** (court
  witnessed: identity fail-closed, real-wire pagination, truncation/drift/bound
  refusals all fire as typed REFUSED[]; 5/5 ×2 runs).
- Burn-down frontier: castle family held by in-flight lane; next census
  candidates after that lane lands are the platform/governance validation
  singletons (35–75 LOC) — all resource-surface-covered, so the uncovered
  frontier is thin; further burn-down should re-census after integration.
