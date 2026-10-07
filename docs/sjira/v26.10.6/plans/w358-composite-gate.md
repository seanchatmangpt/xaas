# W358 — Composite gate dry-run witness (v26.10.6)

Subject: /Users/sac/xaas @ feat/playwright-surface, 2026-10-06, lane W358.

## Stage classification (`lib/mix/tasks/xaas.verify_and_commit.ex`)

Order per source (lines 111–123 + commit stage):

| stage | class | mechanism |
|---|---|---|
| compile `mix compile --force --warnings-as-errors` | CHECK-ONLY (writes only `_build`) | subprocess |
| migrate `mix ecto.migrate` | MUTATING (dev DB `xaas_dev`) | subprocess |
| test `mix test` | CHECK-ONLY (sandboxed DB) | subprocess |
| mock-grep `scan_mock_usage(["test","lib"])` | CHECK-ONLY (pure read) | in-VM fun |
| git add -A | MUTATING (index) | subprocess |
| git status --porcelain | CHECK-ONLY | subprocess |
| git commit -F | MUTATING (history) | subprocess |

No `mix format` stage exists in the task (format is not gated there).
Task source was inspected before running anything; only non-mutating stages
were executed per lane contract.

## Real outputs

### a. Mock gate — PASS

Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW358 mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'`

Exit 0. Verbatim result line: `[]`
(two benign warnings preceded it: PromEx.DashboardUploader Grafana nxdomain,
os_mon teardown lines.)

### b. Format check — FAIL (4 files, not reformatted per contract)

Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW358 mix format --check-formatted`

Exit 1. Unformatted files (verbatim):

- /Users/sac/xaas/lib/xaas_web/controllers/health_controller.ex
- /Users/sac/xaas/test/xaas_web/a2a/v1_sse_test.exs
- /Users/sac/xaas/test/xaas/generated/registry_drift_guard_test.exs
- /Users/sac/xaas/test/xaas/receipt/r_projection_test.exs

`mix format` itself was NOT run — the tree carries other lanes' in-flight edits.

### c. Compile floor

Covered by lane W335 — skipped here, cited.

## Verdict

**gate-ready-except-format.** Mock gate clean; format gate fails on 4 files
owned by / touching other lanes' in-flight work (health_controller.ex,
v1_sse_test.exs, registry_drift_guard_test.exs, r_projection_test.exs).
Integration coordinator should run `mix format` once at integration before
the composite gate, not per-lane.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW358` — DENIED by permission system at
2026-10-06 (session W358). Directory `_build-laneW358/` remains on disk
(~2-3 GB test build). Coordinator must delete it at integration.
