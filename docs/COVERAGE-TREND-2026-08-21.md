# Coverage Trend 2026-08-21

Measure-phase report on `mix xaas.capability_coverage`: a real 3-run repeatability check
against the current dev Postgres database, and the real historical trend recovered from
this repo's own git history. No numbers below are estimated or interpolated — every value
is either a live run captured today or a value quoted verbatim from a cited commit.

## Repeatability: 3 consecutive real runs, 2026-08-21

Command run three times in immediate succession from a clean shell, each run's full
stdout+stderr captured to disk:

```bash
cd ~/xaas && mix xaas.capability_coverage
```

Summary block, identical across all three runs:

```
Total real Postgres-backed Ash resources: 75
Resources with at least one real persisted row: 5
Resources with zero rows: 61
Resources that errored on count: 9
Coverage (resources with >=1 real row / total): 6.7%
```

### What stayed constant

- **Resource-count field (75)** — identical across all 3 runs. Deterministic: comes from
  `Ash.Domain.Info.resources/1` enumerating compiled modules across the 7 domains, filtered
  to `AshPostgres.DataLayer` — a schema read, not a data read.
- **Errored-count field (9)** — identical across all 3 runs, and the identical 9 named
  resources errored every time: 8 with `Ash.Error.Invalid.TenantRequired` (multitenant
  resources the task queries without a tenant: `ApprovalBackupRetentionChange` +
  `.Version`, `ApprovalDeploymentQuarantine` + `.Version`, `ApprovalDrFailover` +
  `.Version`, `ApprovalLegalHoldRelease` + `.Version`) and 1 with `Required primary read
  action for Xaas.Ledger.EventLog` (no primary read action defined on that resource).
  Deterministic: both error classes are static properties of resource definitions, not of
  current row data.
- **Row-count field per resource, and the derived with-rows/zero-rows/coverage-% fields**
  — also identical across all 3 runs in this check: the same 5 resources
  (`AutofdePlannerCacheHotset`, `AutofdePlannerCacheStats`, `AutofdePlannerCandidate`,
  `AutofdePlannerCatalog`, `AutofdePlannerMatch`) held exactly 5 rows each in every run;
  all other 61 non-errored resources held 0 rows in every run. This field is legitimately
  allowed to differ run-to-run if concurrent work writes to the dev DB between runs — no
  such write happened during this check, so it held steady rather than being structurally
  guaranteed to.
- Byte-for-byte diff confirms this: after stripping the per-query `[debug] QUERY OK ...
  db=Xms decode=Yms queue=Zms idle=Wms` timing lines (Ecto's own logger timestamps, which
  necessarily vary run to run), all three run outputs are **identical** (`md5
  cb635e95057507de3682388f1c1cae0c` for all three stripped files).

### What varied (and why that's expected, not a defect)

- Only the Ecto debug-log timing fields (`db=`, `decode=`, `queue=`, `idle=` millisecond
  values on each `[debug] QUERY OK source="..."` line) differed between runs. These are
  wall-clock query-latency measurements the Postgrex/Ecto logger emits per query — they are
  expected to vary with every execution and are not part of the task's reported coverage
  fields.

### Repeatability verdict

All three runs are deterministic on the schema-derived fields (resource count, errored
count, and which specific resources error) and, in this instance, also stable on the
row-count-dependent fields because no concurrent writer touched the dev database in the
run window. The task's own design (`Ash.count/2` against the live DB) means the row-count
fields are read-time-of-check values, not cached/derived constants — they are allowed to
drift under concurrent load, they simply did not this time.

## Trend: real historical readings from git

Searched this repo's full git history (`git log -p --all -- lib/mix/tasks/
xaas.capability_coverage.ex`, plus `git log --all -i --grep="coverage"` and
`--grep="capability_coverage"` over all commit messages) for prior real coverage readings.

| Date | Commit | Total | With rows | Zero rows | Errored | Coverage |
|---|---|---|---|---|---|---|
| 2026-08-20 | `bd1e433f1ea6293579d0a04ef36e4d70377b1c66` | 65 | 1 | 63 | 1 | 1.5% |
| 2026-08-21 (today) | `e90d478f4266351c79db49d43e61eefd64db93d4` (HEAD) | 75 | 5 | 61 | 9 | 6.7% |

- **`bd1e433`** (`feat: real capability coverage report (mix xaas.capability_coverage)`) is
  the commit that both introduced the mix task and cited its first real run's output in the
  commit message: "Total real Postgres-backed Ash resources: 65 ... Resources with at least
  one real persisted row: 1 ... Resources with zero rows: 63 ... Resources that errored on
  count: 1 (Xaas.Ledger.EventLog -- no primary read action defined on that resource) ...
  Coverage (resources with >=1 real row / total): 1.5%". Verified by `git show bd1e433 --
  lib/mix/tasks/xaas.capability_coverage.ex` and `git log -1 --format='%B' bd1e433`.
- **A second prior real reading was searched for and not found.** `git log --all -- lib/
  mix/tasks/xaas.capability_coverage.ex` shows exactly one commit touching that file
  (`bd1e433`, the file's creation) — no later commit modifies or re-runs it with a cited
  result. Commits mentioning "coverage" in the interim (`7bea457`, `53788ea`, `f411099`,
  `2cdda3c`) all describe a *different* metric: `mix xaas.close_coverage_gap`'s SPARQL
  `COUNT(?s)` over 5 K-graph classes surfaced via `Xaas.SparqlBridge.to_turtle/0` — not the
  `mix xaas.capability_coverage` Postgres-resource-coverage percentage this report tracks.
  **No prior real reading found** for a second `mix xaas.capability_coverage` data point
  between `bd1e433` and today; the trend below is two points, not three, because that is
  what git history actually contains.

### Trend read (two real points only)

- 2026-08-20 (`bd1e433`): 1.5% (1/65)
- 2026-08-21 (today): 6.7% (5/75)

Both the numerator (resources with rows: 1 -> 5) and the denominator (total resources: 65
-> 75) grew between the two readings — 10 new Postgres-backed Ash resources were added to
the domains in the interim (consistent with the `feat:` commits between `bd1e433` and
`e90d478` adding new Governance/Operations resources), and the `close_coverage_gap` MAPE-K
loop (`53788ea` onward) drove the 5 AutofdePlanner* resources from 1 exercised resource
to 5, each now holding 5 rows. No third historical data point exists to compute a rate;
reporting only what is evidenced.

## Evidence index

- Repeatability run outputs (today): captured to a local scratch dir during this check,
  not committed (raw Ecto debug logs, not durable artifacts); the summary block reproduced
  above is the load-bearing content, quoted verbatim from three real `mix
  xaas.capability_coverage` executions.
- `bd1e433f1ea6293579d0a04ef36e4d70377b1c66` — first and only prior real
  `capability_coverage` reading (1.5%), plus the mix task's original source.
- `e90d478f4266351c79db49d43e61eefd64db93d4` — repo HEAD at the time this report's runs
  were executed.

## See Also

- `lib/mix/tasks/xaas.capability_coverage.ex` — the task under measurement.
- `lib/mix/tasks/xaas.close_coverage_gap.ex` — the separate SPARQL-based MAPE-K coverage
  loop referenced above; tracks a different metric over a 5-class K-graph subset, not the
  75-resource Postgres coverage this report covers.
