# Boundary receipt: qualify-boundary(ash_a2a, cap-orchestration)

- Wave: SA2A release v26.9.17 qualification, agent 1/10 (r1 retry; first spawn died to usage-limit after a partial run)
- Date: 2026-09-17
- Subject: /Users/sac/ash_a2a (no other repo or worktree touched)
- Requested pin: `02d8616f72014453808f3e09dbc8a2ca9b6877dc` — **HEAD MOVED**: observed `801374a9642c45e6e4299056bac92e5f29e2961e` (branch `main`, clean tree, ahead of origin 111). `02d8616` verified ancestor; the 3 intervening commits (`5cd185f`, `1962b8f`, `801374a`) add only test fixtures + CHANGELOG, no lib code. **Re-pinned: all verification at `801374a`.**
- Standing: **PARTIAL_ALIVE** — FOND task verdict: **blocked** (typed, environmental; see classification)

## Court (repo-defined, .github/workflows/ci.yml)

`mix deps.get` → `mix format --check-formatted` → `mix compile --warnings-as-errors` (dev) → `mix test` (real Postgres :55432 per ci.yml:22-30, config/test.exs:39-45) with native `hddl_cli` (Rust 1.97.1 locked) built per ci.yml:57-58. `bin/ci-local.sh` (act) is repo-disclosed as unable to complete on this machine class.

## Commands + exit codes (this session)

| command | exit |
|---|---|
| `git rev-parse HEAD` | 0 → `801374a…`, clean tree (also re-checked clean at end) |
| `mix deps.get` | 0 (advisory notices only) |
| `mix format --check-formatted` | 0 |
| `mix compile --force --warnings-as-errors` (dev = the court compile gate, fresh) | **0** ("Generated ash_a2a app") |
| `cargo +1.97.1 build --release --locked` × native/hddl_cli, native/graphlaw_host | 0 / 0 (19.6s, 1m30s) |
| `mix test` (final run) | exit **2** — **1912 tests, 0 failures**, 58 doctests, 19 properties, **8 invalid**, 1 skipped (14 excluded), 606.2s. Invalids are exactly `AshA2A.ObanDeliveryQualificationTest` + `AshA2A.ScheduledSweepQualificationTest` (4+4), whose `setup_all` raises-by-design with setup instructions when Postgres :55432 is unreachable — the repo's documented no-Postgres signature (ci.yml:5-18). |
| `MIX_ENV=test mix compile --force --warnings-as-errors` | 1 — falsifier, see below |
| containerized-court attempts 1 & 2 | dead (colima), see incident |

## Incident + narrow repair (this agent's own damage, fully disclosed)

- My first container attempt mounted empty named volumes over `/work/native/hddl_cli/target` etc.; when it died (colima event 18:26Z), the flush wiped gitignored host artifacts I had verified present minutes earlier: `native/hddl_cli/target/release/hddl_cli` (built Sep 16). Next court run: 49 failures, all `:hddl_cli_not_built` / `:graphlaw_host_not_built` (repo's loud raise convention).
- Repair: rebuilt both binaries with the CI-pinned toolchain and `--locked` (exit 0 ×2) — exactly the commands the repo's own diagnostics print. Re-ran court → **0 failures**. Git tree never touched (clean before, during, after).
- Colima was simultaneously degraded: `docker logs` I/O error, container state contradiction, containerd content-store blob `input/output error` (killed the containerized-court alternate and the postgres container). Postgres service restored after (`ash_a2a_test_pg` Up, VM-side).

## Environment blocker (typed, machine-level, needs operator authority)

Host port 55432 is squatted by a stale Docker Desktop backend (`com.docker`, pid 62485, IPv6 `*:55432` capturing loopback); this docker is colima, whose forward for published 55432 can therefore never bind. Freeing it requires quitting Docker Desktop (shared machine; other agents/processes; no operator authority held). All in-authority alternates attempted: containerized full court (twice; dead via colima corruption), non-55432 publishing (config pins 55432; env-override absent from config — verified), subject-config modification (rejected: unlawful for infra convenience).

## Capability evidence (owns predicate: REAL — orchestration surface implemented, not aspirational)

All cites re-verified at `801374a`:

- Agent card: `lib/ash_a2a/info.ex:76` (`agent_card/2` → `%A2A.AgentCard{}`); `lib/ash_a2a/capability_index/agent_card_builder.ex:14` (`build_agent_card/2`).
- A2A dispatch: `lib/ash_a2a/dispatcher.ex:127` (`dispatch/3`); supervised agent `lib/ash_a2a/agent.ex:1`; consequence boundary `lib/ash_a2a/command_bus.ex:1`.
- Admission + SA2A transport: `lib/ash_a2a/semantic/admission.ex:1`; SA2A state machine `lib/ash_a2a/sa2a/state_machine.ex:1` — `RECEIVED -> PARSED -> IDENTIFIED -> STRUCTURALLY_VALID -> SEMANTICALLY_VALID -> CLOSED -> FALSIFIER_CLEAN -> ADMITTED` (lines 6-7; deliberately stops at ADMITTED, lines 9-11); conformance court `lib/ash_a2a/sa2a/conformance.ex:1`; `lib/mix/tasks/ash_a2a.sa2a_conformance.ex:1`.
- Orchestration loop: HDDL decomposition `lib/ash_a2a/planning.ex`, `lib/ash_a2a/planning/hddl_solver.ex:1`, `lib/ash_a2a/hddl_operator.ex:1`, native FOND solver `native/hddl_cli`; bounded episodes `lib/ash_a2a/semantic/episode.ex:1` (terminal conditions line 11: `completed | quiescent | refused | resource_exhausted | bound_reached`; bound guards lines 925-1016).
- On-point dogfood: `test/ash_a2a/chicago/sa2a_v26_9_17_fond_qualification_test.exs:6-19` models THIS wave's Orient→CloseBoundaries→Ep1→Ep2→Certify loop and its grounding names **`ash-a2a/cap-orchestration` ALIVE**. That test passes in the final run.

## FOND classification

- **build-broken? NO** — compile gates green (dev fresh exit 0), 0 test failures at final run.
- **unsupported? NO** — exact subject contains the orchestration + admission + SA2A transport surface (file:line above); no missing extension to report.
- **qualified? NOT YET** — the repo's own court did not fully execute: the async delivery-transport slice (8 tests across Oban delivery + scheduled sweep qualification — material to an "admission + SA2A transport" boundary) is invalidated by unavailable Postgres :55432, an environment condition outside the subject.
- **blocked** (typed): completion requires exactly one operator-level act — free host port 55432 (quit Docker Desktop, or recycle colima at a safe moment) with `ash_a2a_test_pg` running — then re-run `mix test`; given 1912/1912 executable tests pass, expected outcome is 0 failures, 0 invalid.
- **Standing: PARTIAL_ALIVE.**

## Falsifiers attempted

1. Stricter-than-court compile: `MIX_ENV=test mix compile --force --warnings-as-errors` → exit 1, reproduced at `801374a`: 36 warnings — Ash "Domain … not present in config :ash_a2a, ash_domains" for deliberately-unregistered fixture domains (`test/support/cancel_fixture.ex:53`, `auth_plug_fixture.ex:42`, `error_class_fixture.ex`, `fixture.ex:299` ignored-argument block) omitting the repo's own opt-out `validate_config_inclusion?: false` (pattern: `test/support/fixture.ex:390-401,450`). CI compiles dev only (ci.yml:74) → LATENT defect, invisible to repo gates, above-court bar. Not repaired (repair sanctioned only for build-broken).
2. Prior-wave host log (`/tmp/uzc/ash_a2a-mix-test-full.log`, 01:03, 22 failures incl. Erlang "corrupt atom table") — discarded as load-corrupted evidence; superseded by this session's clean 0-failure run.
3. Binary-absence probe: deliberately let the wiped-binary failures speak, then falsified "repo is broken" by rebuilding → 0 failures. Confirms failures were environmental, not subject defects.
4. Court-environment adversarial probes: port-squat lsof/docker-log/nc/psql matrix; container-vs-bridge-IP isolation; fresh-port control (55433 worked) — isolated the squatted 55432 as the sole service blocker.

## What the operator did NOT have to write

Zero operator bytes on the 産面 or 法面: no code, config, tests, docs, or commits. Agent executed the court, diagnosed 49 failures to a self-inflicted artifact wipe, rebuilt binaries, ran the falsifier matrix, and wrote this receipt. The one operator keystroke still needed is a machine-authority act (free port 55432), not a write.
