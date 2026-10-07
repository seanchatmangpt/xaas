# W78 Integration Baseline — autofde-lab

- Repo: `/Users/sac/autofde-lab`
- Branch / exact subject: `feat/doctrine-lab` @ `2a3d064e30df4da2bf465a2fbaaefe6e84da0325` (HEAD at run time, verified via `git rev-parse HEAD`)
- Lane: W78, v26.10.6 convergence, integration baseline. No fixes, no git mutations.
- Date: 2026-10-06

## Test command (from Justfile)

Canonical loop is the Justfile `test:` recipe (line 58): `just test` = `.venv/bin/python -m pytest tests -q -n 4` with 15 `--ignore` entries (tests/solvers/cpp, tests/solvers/python, tests/scheduling, tests/ecosystem, tests/domains, tests/flight_planning, and 9 named heavy files: terraform_guards, dspy_mcp_planner_loop_chicago, mcp_ocel_instrumentation_chicago, powl/test_import_separation, self_play_dspy_{advanced,all_domains,turbofieldfare}_chicago, test_chatman_wasm, test_import_all_submodules, evidence/test_level4_witness_falsifiers_chicago).

Per Justfile commentary, everything `just test` excludes still runs in `just test-full` (5 pytest invocations matching CI's `integration` job). `test-full` and `test-level4*` were NOT run — heavy externals (Ray/rllib, torch_geometric, unified-planning, MCP server suites, federation-bound Level-4 suites). No docker/kind was needed for what ran; all executed tests were local (real PDDL engine, real gymact subprocesses where present).

## Counts (verbatim from run output)

Log: `/tmp/w78_r3.log` — identical pytest invocation as `just test`, plus `--tb=no` (added only to suppress traceback volume; invocation otherwise byte-identical). pytest's aggregate `N failed, M passed` line does not appear in this configuration (suppressed under xdist+tb=no), so counts are tallied from the run's own progress markers and short-summary lines:

| outcome | count |
|---|---|
| passed (progress `.` markers) | 2685 |
| failed (`F` markers / `FAILED` summary lines) | 92 |
| errors (`ERROR` summary lines: collection + setup) | 68 |
| skipped | 322 (progress `s` markers 321; SKIPPED-summary units 322) |
| executed total | 3121 (2685 passed + 92 failed + 23 in-run setup-error markers + 321 skipped; the 68 ERROR summary lines additionally cover 45 collection-error files whose tests were never collected) |

Run-to-run variance: first `just test` run (`/tmp/w78_test.log`, 3 runs of the suite this session: w78_test, w78_full, w78_r3) showed 93 FAILED vs 92 — one-test flake in `tests/wd_fa/test_wd_fa_court.py`.

Failure classification (from the full-tb run `/tmp/w78_full.log`):

### Class A — environment/import-shape (dominant, majority of red)

1. `ImportError: cannot import name 'DeterministicPlanningDomain' from 'autofde_lab' (unknown location)` — 34 error occurrences plus a large share of the 92 failures. Origin: `src/autofde_lab/hub/domain/cloudgoat_iam_privesc/cloudgoat_iam_privesc.py:60` and sibling hub-domain modules importing compat names from `autofde_lab` top level. "(unknown location)" = namespace-package resolution; a bare-interpreter import (`from autofde_lab import DeterministicPlanningDomain` with `.venv/bin/python`) SUCCEEDS — fails only under pytest/xdist sys.path handling. Install/resolve-shape issue, not a code regression at this subject.
2. Missing optional deps, hard-imported without skip guards: `dspy` (~20 occurrences), `pyDatalog` (12), `tpot` (10). Not installed in `.venv`.
3. Downstream of A.1: `DecisionRefusal: SKD-FABRIC-002` ×5 (empty domain registry), `tests/test_identity_anti_vacuity.py` ×4 (`assert []` — empty domain/solver entry-point registry), `tests/ocel/test_no_self_attestation.py` ×4 (`module 'autofde_lab' has no attribute 'ocel'`).

### Class B — real assertion failures against real collaborators (the true red set)

- PDDL-engine plan-not-found cluster (~8-10 tests): platform-console domain mutation/roundtrip/benchmark/stress suites, `assert 2 == 0` / `0 = pddl_engine.EXIT_PLAN_FOUND` — real engine refuses to plan.
- Standing assertions `UNSUPPORTED == ALIVE` (~9 tests): reasoning payoff/psro/production-boundary suites.
- `tests/iec/test_residue_census_chicago.py::test_committed_receipt_replays_byte_for_byte` — committed receipt does not replay byte-for-byte at this subject.
- `tests/sa2a/conformance/test_crown_release_fence_wiring.py::test_release_tag_is_a_single_constant_and_release_urn_is_derived`
- `tests/wd_fa/test_wd_fa_court.py` (2) — pm4py POWL/object-centric evidence discovery.
- `tests/e2e`, `tests/cmca`, `tests/semantic_models`, `tests/fabric/test_phi_dispatch_chicago.py` (4), `test_phase_h_trigger_chicago.py` (3), `test_decision_result_to_plan_lines.py` (3), assorted fabric/cli/agent suites — remainder of the 92, most sharing the Class A.1 import-shape root.

Full FAILED list verbatim in `/tmp/w78_r3.log` (92 lines) and `/tmp/w78_full.log`.

## Receipt fields

- Exact subject: autofde-lab `feat/doctrine-lab` @ `2a3d064e` — unchanged during lane; no git mutations, no fixes.
- Commands/exits: `just test` ×3 (exit 1 each); `pytest --collect-only -q` interrupted at 39 collection errors (matches Class A.1); direct venv import probe (exit 0).
- Verification ladder: baseline only (single hot-loop partition); full ladder NOT run.
- Standing: BLOCKED-red baseline recorded; Class A is environmental (venv install shape + missing optional deps), Class B is the real defect surface for the convergence lane.
