# W628 — ash_a2a suite leg of OS-20 verification (v26.10.7)

Standing: **PARTIAL_ALIVE** — suite witnessed with real tails; 3 deterministic failures, all root-caused; 20 flaky-under-load pass on rerun.

## Subject

- Repo `~/ash_a2a` @ HEAD `b588c55c22580885e9fb56f18a4dac4a3f0133ba` (matches W608).
- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW628 mix test.all --max-cases 6`
- Prereqs verified before run: `native/hddl_cli/target/release/hddl_cli` present, Postgres accepting on 55432, cargo present.
- Registered figure ~3,708 tests is **stale**: real count is **4,706 tests + 124 doctests + 51 properties** (4,531 plain tests). 11 skipped, 13 excluded, 34 invalid reported by the runner.

## Results

- Full run: `Result: 4683/4706 passed (124/124 doctests, 51/51 properties, 4508/4531 tests), 34 invalid, 11 skipped, 13 excluded` — `Failed: 23 tests`, process EXIT=2. Log: `/tmp/w628-a2a-full.log`.
- Single batch rerun of all 15 failing files: **61/64 passed** — only 3 failures persist → **20 of 23 are flaky-under-parallelism** (README-documented port-bind/peer races at `--max-cases 6`). Log: `/tmp/w628-rerun1.log`.

## Deterministic failures (3) — classification

| # | Test | Classification | Evidence |
|---|------|----------------|----------|
| 1 | `AshA2A.SupplyChain.ReleasePathTest` "version coherence" | **W618 version-bump interaction** | `docs/reference/a2a-spec-version-mapping.md` line 9 still `Version: v26.10.5` vs mix.exs `26.10.7`; bump commit `e0fb769e chore(release): bump version to 26.10.7` did not touch the doc (`git log` on the doc: last commit `4098a6af align spec-version mapping to 26.10.5`) |
| 2 | `AshA2A.A2ATransport.SpecMappingDocTest` "Version line tracks mix.exs" | **W618 version-bump interaction** | Same root cause, same doc file |
| 3 | `AshA2AArchitectureVerifierTest` "checks/0 reports all ten original architecture invariants..." | **Pre-existing, environment/perf** | 300s test timeout inside `AshA2A.Chicago.Runner.run_court/3` (`lib/ash_a2a/chicago/runner.ex:367`); reproduces alone (`mix test test/ash_a2a_architecture_verifier_test.exs` → 10/11, EXIT=2, same timeout). A Chicago court exceeds its 300s test timeout on this host even without suite load |

## Flaky (20, pass on rerun)

Includes: 8× `SecurityValidatorsTest`, 2× `CheckGateTest`, `Rfc004AgentScopeTest`, `LibclusterHordePocTest`, `ChicagoRollupTest`, `FreedomGymHddlPlanTest`, `SemanticConformanceEffectiveTest`, `AgentCommandBusTest`, `MutationHarnessTest`, 3× `HooksCascadeTest`. Consistent with README's documented `--max-cases 6` port-bind/`peer` races.

## Receipt fields

- **Commands/exits**: as above; full run EXIT=2, rerun EXIT=2, isolated AV run EXIT=2.
- **No commits made**; only files written: this receipt. No `test/` additions were needed (no gap — the repo's own coherence courts already catch the staleness).
- **Lane build root `_build-laneW628` LEFT IN PLACE** — deletion was denied by the permission system; per the directive's "else leave" clause it remains at `/Users/sac/ash_a2a/_build-laneW628` for coordinator cleanup.
- **Falsifier for the fix lane**: after updating `docs/reference/a2a-spec-version-mapping.md` line 9 to `v26.10.7`, both version tests pass (fails-when-reverted already witnessed — they fail now).
- **OPEN for release**: the 26.10.7 bump must land the missing doc restatement edit, or release coherence stays red.
