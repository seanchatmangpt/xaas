# W791 — `mix xaas.doctor` consolidated tree-health task

- **Standing**: PARTIAL_ALIVE (task executes and emits valid JSON on the exact subject; not yet merged — uncommitted per lane discipline)
- **Subject**: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf6 (uncommitted lane files: `lib/mix/tasks/xaas.doctor.ex`, this receipt)
- **Date**: 2026-10-07
- **Lane**: W791 (v26.10.6 campaign fan-out)
- **Backlog class**: campaign re-derives tree health ad hoc (W760 gate, W755 mock sweep, W760 warnings count)

## Change (μ/diff)

- NEW `lib/mix/tasks/xaas.doctor.ex` — `Mix.Tasks.Xaas.Doctor`, emits one JSON
  document `{checks: [{name, status: pass|fail|warn, detail}]}` to stdout:

  | check | real command/evidence | fail? |
  |---|---|---|
  | `mock_gate` | calls `Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"])` | yes |
  | `eu_ai_act_compile` | `Code.string_to_quoted/1` over every `test/eu_ai_act/**/*.exs` | yes |
  | `lane_leases` | census of `_build-lane*/` dirs + recursive byte totals (informational) | no |
  | `eu_ai_act_file_count` | `Path.wildcard` count of `test/eu_ai_act/**/*.exs`, band 1080..1320 | no (warn only) |
  | `receipt_census` | count of `docs/sjira/v26.10.6/plans/*.md`, warn any < 500 bytes | no (warn only) |

- NEW this receipt.

Generated-vs-handwritten: 100% handwritten (no ggen pack covers a mix-task
surface in the bound profile; explicit UNSUPPORTED(generator-capability) note).

## Verification ladder (real output)

- `mix compile` (MIX_ENV=test) — compiled clean on the first pass; warnings in
  pre-existing deps only (`ash_affidavit`, `explorer`).
- `mix xaas.doctor` — executed for real in `_build-laneW791` (seeded from the
  shared `_build/test`, then incremental compile). First run exposed two real
  defects in the task itself (nil accumulation in the compile-check fold;
  `Path.wildcard/3` undefined on elixir 1.20.2), both fixed and re-run.
- Clean-run output (exit 0):
  `mock_gate=pass, eu_ai_act_compile=pass (16 files parsed), lane_leases=pass
  (23 lanes, ~16.6 GB), eu_ai_act_file_count=warn (16 outside 1080..1320),
  receipt_census=warn (581 receipts, 9 < 500 B)`.
- JSON round-trip: last non-empty stdout line decoded by python3 `json.load`
  — valid JSON, 5 checks. Mix compiler logs precede the document on stdout
  when a compile triggers; documented last-line convention.
- Falsifier witnessed: injected `test/zz_w791_inject_test.exs` containing
  `import Mox` → `mock_gate=fail`, exit code 1; file removed → clean rerun
  back to all-pass (warn-only on 4/5), exit 0. Injection fixture deleted.

## Deviations (typed)

- `DEVIATED(BUILD_ROOT_SEED)`: fresh `_build-laneW791` was provisioned but a
  from-scratch dep build exceeded the background time budget twice (and hit a
  transient `enospc` at 865MiB free mid-campaign). Final lane root was seeded
  via `rsync -a _build/test/ _build-laneW791/test/` then incrementally
  compiled under MIX_ENV=test — same toolchain (asdf 1.20.2-otp-28), no dev
  compile. Lane lease `_build-laneW791` deleted at integration per the
  lane-lease cleanup law.
- `BLOCKED(TRANSIENT, cross-lane)`: a concurrent lane's in-flight edit to
  `lib/xaas/platform/route_feature_flags.ex` (duplicate `patch /:id` route)
  broke whole-app `mix compile` on the shared tree mid-run; later resolved by
  that lane. Not this lane's file. The doctor task's own checks are
  file-level and independent of that module.
- `BLOCKED(TRANSIENT, cross-lane)`: a concurrent lane's in-flight edit to
  `lib/xaas/platform/route_feature_flags.ex` (duplicate `patch /:id` route)
  breaks whole-app `mix compile` on the shared tree mid-run. Not this lane's
  file; unowned-here. The doctor task's own checks are file-level and
  independent of that module.

## Falsifier

- `mix xaas.doctor` exits nonzero and prints machine-checkable JSON where any
  mock hit or eu_ai_act syntax error exists; injectable by adding
  `import Mox` to any test file and re-running.

## Standing chain

- W755 mock sweep / W760 gate re-derived here by reuse of
  `scan_mock_usage/1` — no re-implementation.
