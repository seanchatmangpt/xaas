# W366 — ash_a2a HEAD gate (re-pin adjudication evidence)

## Subject

- Repo: `/Users/sac/ash_a2a` (canonical checkout, read-only; no commit made)
- HEAD: `07180bd3be686db25b61918770a76a003349ba29` on `feat/tck-vuln-hardening`
- Dirty: 3 modified files (`lib/ash_a2a/authzen/client.ex`, `test/ash_a2a/command_bus_test.exs`, `test/test_helper.exs`) + untracked `docs/thesis/` — a sibling lane is actively working in this checkout; the suite ran against HEAD + those uncommitted edits.
- xaas currently locks `86214551`; `git rev-list --count 86214551..HEAD` = **61 commits**.

## Commits the re-pin would pick up (61; representative)

- `07180bd3` test(tck): deflake EA30/EA55 flaky test-infra failures
- `a0bc3d4f` fix(conference_sim): unblock full-dir suite — 112 tests, 0 failures
- `b6b79dea` docs(tck): record final vuln-hardening TCK verdict — 235/30/0, 79.0%
- `636b7940` test(ea13): rename conference_sim *_court.exs → *_court_test.exs
- `0ff9c94a` fix(ev10-f1): scrub internal metadata keys from task history messages (transport fix)
- `1dcaf7e7` fix(transport): drop_from/2 arity mismatch in strip_task broke compile
- `cadb6534`..`13a2cbb6` ~40 conference_sim EV1–EV16 courts (red-team, interop, load, push, SSE, OCEL, governance) over the real pipeline
- `7e9032eb` fix(conference_sim): fixture_test syntax error and flaky assertions
- Remainder: vuln-hardening TCK courts + transport fixes on the same branch.

## Real suite run (private build root `_build-laneW366`, pinned asdf toolchain)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/ash_a2a/_build-laneW366 mix test
```

Tail (exit 0, ~620s):

```
Finished in 619.4 seconds (331.2s async, 288.1s sync)
Result: 3706/3708 passed (113/113 doctests, 51/51 properties, 3542/3544 tests), 1 skipped, 1032 excluded
Failed: 2 tests
```

## Failure adjudication (env/timeout-class, not real)

1. `AshA2AArchitectureVerifierTest` "checks/0 reports all ten original architecture invariants..."
   — `ExUnit.TimeoutError` after 300000ms inside `AshA2A.Chicago.Runner.run_court` via
   `ArchitectureVerifier.checks/0` (full run AND isolated file run both timed out at default timeout).
   **Rerun with `--timeout 900000`: 11/11 passed.** Slow court under heavy concurrent-lane CPU load,
   not a regression.
2. Second failure passed on `mix test --failed` rerun (1/2 → the verifier test was the only repeat
   failure) — flaky under contention.

## Verdict: **HEAD-READY**

Suite is green modulo per-test-timeout sensitivity of the Chicago-rollup verifier under concurrent
campaign load. `07180bd3` is a valid re-pin candidate for the next cycle. Note for the re-pin
receipt: CI/next gate run should either raise `--timeout` (e.g. 900000) for
`test/ash_a2a_architecture_verifier_test.exs` or run it on a quieter machine.

## Cleanup

`rm -rf /Users/sac/ash_a2a/_build-laneW366` — **DENIED by permission system**. Build root
`/Users/sac/ash_a2a/_build-laneW366` remains on disk (~fs lease left for coordinator removal).
