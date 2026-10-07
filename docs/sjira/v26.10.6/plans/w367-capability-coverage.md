# W367 — Capability coverage machinery + fail-closed ingest witness

Lane W367, v26.10.6 convergence campaign. Subject: `/Users/sac/xaas` @ `feat/playwright-surface`.
Date: 2026-10-06. Contract-respecting writes only (this file; `_build-laneW367` lease).

## 1. Static read of the coverage task

`/Users/sac/xaas/lib/mix/tasks/xaas.capability_coverage.ex`:

- Enumerates 7 hardcoded domains (`Xaas.Accounts, Billing, Governance, Ledger,
  Marketplace, Operations, Platform`) via `Ash.Domain.Info.resources/1`.
- Filters to `AshPostgres.DataLayer` resources only.
- Runs a REAL `Ash.count/2` (read-only, `authorize?: false`) per resource against
  `Xaas.Repo` → the real, current Postgres. DB-backed, not static analysis.
- Errors per-resource are captured structurally (`{:error, %{exception, message}}`),
  never crash the task; machine-readable summary line at the end.

## 2. Real run — coverage

Command:

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW367 \
  mix xaas.capability_coverage
```

Cold build (~11 min full dep compile, fresh lane build root). Exit code: **0**.

Output tail (verbatim from the run log, lines 1-10 of 10):

```
Xaas.Operations.RouteCastleRun                                route_castle_runs           0
Xaas.Operations.RouteCastleSchedule                           route_castle_schedules      0
Xaas.Operations.RouteCastleSunset                             route_castle_sunsets        0
Xaas.Platform.RouteFeatureFlags                               route_feature_flags         0
Xaas.Platform.RouteOrgsCustomDomain                           route_orgs_custom_domains   0
Xaas.Platform.RouteProjects                                   route_projects              0
Xaas.Platform.RouteProjectsBackups                            route_projects_backups      0
Xaas.Platform.RouteSecrets                                    route_secrets               0
Xaas.Platform.Webhook                                         platform_webhooks           0
Xaas.Platform.WebhookDelivery                                 platform_webhook_deliveries 0
Xaas.Sa2a.Execution                                           sa2a_executions             0
```

Summary lines (verbatim):

```
Total real Postgres-backed Ash resources: 80
Resources with at least one real persisted row: 0
Resources with zero rows: 71
Resources that errored on count: 9
Coverage (resources with >=1 real row / total): 0.0%
```

## 3. Real run — ingest fail-closed

`/Users/sa c/xaas/lib/mix/tasks/ha.sjas.ingest_capability_receipts.ex` raises
`Mix.raise` BEFORE any DB write when the default receipt file is absent —
no-side-effect path confirmed from source (lines 29-33). Run:

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW367 \
  mix xaas.ingest_capability_receipts
```

Verbatim raise (two runs, identical both times):

```
** (Mix) No receipt file at /Users/sac/chatman-ecosystem/target/weaver-live/receipt.jsonl -- run weaver-live-matrix.sh first (real, not fabricated).
```

Exit code: **1**. No fake input file created; no `../chatman-ecosystem` artifacts touched.

## 4. Verdict

| witness | result |
|---|---|
| coverage machinery ALIVE | YES — exit 0; enumerated 80 real Postgres-backed Ash resources; per-resource real `Ash.count` vs real Postgres; 71 zero-row, 0 with-rows, 9 count-errored (0.0% coverage against the test-env DB — expected: `MIX_ENV=test` DB is empty) |
| fail-closed ingest raise witnessed | YES — `** (Mix) No receipt file at /Users/sac/chatman-exaas/target/weaver-live/receipt.jsonl -- run weaver-live-matrix.sh first (real, not fabricated).`, exit 1, before any write |

## 5. Cleanup

`rm -rf /Users/sac/xaas/_build-laneW367` — DENIED by permission system (recorded per contract).
Build root `/Users/sac/xaas/_build-laneW367` (~437 MB) remains on disk; coordinator should remove
it at integration per the lane-build-root lease law.