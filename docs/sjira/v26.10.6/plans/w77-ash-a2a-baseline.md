# W77 — ash_a2a Baseline Receipt (v26.10.6 Convergence)

Date: 2026-10-06 · Lane: W77 integration baseline · Operator: Claude (integration lane)

## Subject

- Repo: `/Users/sac/ash_a2a`, branch `feat/tck-vuln-hardening`, HEAD `07180bd3be686db25b61918770a76a003349ba29` (local).
- Pin under evaluation: `origin` tag `v26.10.4` @ `86214551` (what xaas consumes). **The suite ran on the local branch `feat/tck-vuln-hardening` @ `07180bd3`, not the pin** — per lane direction, it is used as the best available proxy for pinned-ref health. The local branch is ahead of the pin (v26.10.5 in mix.exs vs v26.10.4 tag); local-branch results are therefore an upper-bound proxy, not an exact-subject verdict on `86214551`.
- Toolchain: elixir 1.20.4-otp-29 (asdf), MIX_ENV=test.

## Command

```
cd /Users/sac/ash_a2a && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test
```

## Verbatim counts (run 1, full suite)

```
Finished in 585.4 seconds (227.7s async, 357.6s sync)
Result: 3707/3708 passed (113/113 doctests, 51/51 properties, 3543/3544 tests), 1 skipped, 1032 excluded
Failed: 1 test
```

## Verbatim counts (run 2, full suite rerun with full log, /tmp/ash_a2a_full_suite_w77.log)

```
Finished in 515.6 seconds (302.9s async, 212.7s sync)
Result: 3705/3708 passed (113/113 doctests, 51/51 properties, 3541/3544 tests, 1 skipped, 1032 excluded)
Failed: 3 tests
```

Run-1 tail truncated the failure names; run 2 captured all three verbatim:

1. `AshA2AArchitectureVerifierTest` `checks/0` — `ExUnit.TimeoutError` after 300000ms inside `AshA2A.Chicago.Runner.run_court/3` via `ChicagoRollup.check_court/1` (test/ash_a2a_architecture_verifier_test.exs:54). **Flake (load-dependent timeout)**: passes in isolation (`Result: 11 passed`), timeout only under full-suite concurrency. The Chicago rollup runs the full court set inside one test with a 300s cap.
2. `AshA2A.Enterprise.AuthZENClientCourt` "fail-closed: PDP down is a typed refusal" — test/ash_a2a/enterprise/authzen_client_test.exs:330. Match failure: expected `{:error, :pdp_unreachable}` but got `{:ok, %Decision{decision: false, source: "https://court-pdp.example", ...}}` — the client served a **cached decision from an earlier test in the same module** while the PDP was down (cache does not distinguish PDP-down from PDP-up; fail-open through the cache). **Deterministic at file scope** (10/11 when the whole file runs), passes at line scope (1 passed) and in run 1 of the full suite it passed (run 1 had only 1 failure). Order/state-dependent within module.
3. `AshA2A.CommandBusTest` "receipt store crashing between claim and commit fails closed instead of crashing the caller" — test/ash_a2a `command_bus_test.exs:161`, assert_receive timeout at line 193 (`{:result, result}` never arrives, mailbox empty). **Fails in isolation (0/1)** — deterministic, a real defect at this HEAD, not a flake: the crash-injection branch does not deliver a result message to the caller on the fail-closed path.

## Consumer-relevant verdict (for the v26.10.4 pin)

- 3541–3543/3544 tests pass; 1 skip; 1032 excluded. Suite is substantially healthy.
- One deterministic failure (CommandBusTest fail-closed crash-injection) exists on the local branch; whether it exists on the pin `86214551` is UNKNOWN (not run).
- Two flaky/order-dependent failures (architecture-verifier timeout, AuthZEN cache fail-open at module scope) are load/order artifacts, not pin blockers.
- Suite duration ~9–10 min wall clock.

## Environment repair during run (disclosed, permission-only)

101 directories under `/Users/sac/ash_a2a` had lost the owner execute bit (`drw-------`, e.g. deps/yamerl/src). Before any test could run, `find . -type d ! -perm -u+x -exec chmod u+x {} +` restored execute permission on exactly those 101 directories. No file contents changed; git-tracked content untouched (permission bits are not git-tracked). Without this repair, `mix deps.compile yamerl` and test-priv reads fail with "Permission denied".
