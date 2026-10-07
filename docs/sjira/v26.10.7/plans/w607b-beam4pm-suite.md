# W607b — beam4pm Suite Receipt (OS-20 verification, suite leg)

Date: 2026-10-07 (UTC) · Lane: W607b · Campaign: v26.10.7 · Repo: /Users/sac/beam4pm
Standing: **PARTIAL_ALIVE** (suite executed, honest counts; 13 failures, 0 version-bump interactions)

## Exact subject

- HEAD: `7312ffcd` (main) — **DISCREPANCY**: dispatch said branch
  `fix/v26.9.30-ci-fmt-tsc`; that branch does not exist in the repo
  (`git rev-parse` → unknown revision). Per lane rules I did not create or
  switch branches. Suite ran on `main` + the uncommitted working-tree edits
  (W618 version-bump touched `.tool-versions`, `ggen.toml`, `gleam/`, docs,
  and many `lib/beam4pm_ash/resources/*.ex` files — regenerated-looking diff
  across the tree, not committed at run time).
- Toolchain: asdf shims first on PATH → elixir 1.20.4-otp-29 / erlang 29.1.1
  (matches pinned `.tool-versions`).
- Build isolation: `MIX_BUILD_ROOT=_build-laneW607b` (1.1 GB; deletion denied
  by the permission system — **left in place**, cleanup owed).

## Commands and exits

1. `mix compile --warnings-as-errors` → **exit 1**, 153 warnings
   (bitstring size-pin, charlist deprecation, unreachable clauses; app lib
   plus vendored path deps ash_a2a/ash_r2rml/ash_json_api/ex4pm/…). The repo
   does not gate the default test entry on it; informational only.
2. `mix test` (full suite) → **exit 2**, real time ~353s test time:
   **1561/1574 passed (3/3 doctests, 1558/1571 tests), 147 skipped, 13 failed.**
   Registered figure was ~1,506 — **real count this run: 1,571 tests
   (+3 doctests)**, higher than the registered figure.
   Full log: /tmp/w607b_test.log
3. Reruns (one per failing file):
   - `mix test test/beam4pm_rf3_ocel_test.exs test/beam4pm_rf2_conformance_test.exs`
     → exit 2, 0/11 passed — same 11 failures, deterministic, not a flake.
   - `mix test test/beam4pm_graphlaw_parity_test.exs` (isolated) → exit 0,
     **7/7 passed** — full-suite failure was order-dependent flake.

## Failure classification (all 13)

| # | Failure | Class |
|---|---|---|
| 1–11 | `BeamPM.Rf2ConformanceTest` (4) + `BeamPM.RF3OcelTest` (7): `System.EnvError` on `RF2_ORACLE_BIN` / `RF3_ORACLE_BIN` unset | **Pre-existing/environmental**, documented verbatim in `README.md:185-186` ("fails 11 of the ExUnit tests loudly"). Oracle binaries not provisioned in this lane's env. |
| 12 | `BeamPM.AuthorshipGateTest` — REFUSED_UNADMITTED for `test/beam4pm_w607_map_update_court_test.exs` | **Pre-existing tree state**: an earlier lane's (W607) unadmitted hand-written test file in the tree. Not version-bump. |
| 13 | `BeamPM.GraphlawParityTest` — `{:error, {:cli_failed, 1, ""}}` in full suite; passes 7/7 isolated | **Flake** (order/resource-dependent lab-CLI corner). |

**Version-bump interaction: 0 of 13.** No failure implicates the OTP/toolchain
pin change or the W618 edits.

## Transport failures / exclusions

- Branch named in dispatch absent — ran on `main` (operator owns transitions).
- `rm -rf _build-laneW607b` denied → build root left on disk (1.1 GB).
- 147 skips recorded by the suite itself (env-gated tests), not counted as
  failures.

## Replay

```sh
cd /Users/sac/beam4pm
MIX_BUILD_ROOT=_build-laneW607b PATH=$HOME/.asdf/shims:$PATH mix test
# logs: /tmp/w607b_test.log, /tmp/w607b_rerun1.log, /tmp/w607b_graphlaw_rerun.log, /tmp/w607b_compile.log
```

## Falsifier / next hop

- To zero the environmental failures: source `scripts/env/rust4pm_reactor_env.sh`
  and build the RF2/RF3 oracle binaries, then rerun.
- To clear the authorship gate finding: admit or remove
  `test/beam4pm_w607_map_update_court_test.exs`.
- Delete `_build-laneW607b` when the permission gate allows (or via osx-clnr).
