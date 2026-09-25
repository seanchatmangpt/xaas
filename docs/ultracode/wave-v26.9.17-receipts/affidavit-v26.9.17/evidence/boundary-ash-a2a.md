# Boundary receipt: qualify-boundary(ash_a2a, cap-orchestration)

- Wave: SA2A release v26.9.17 qualification, agent 1/10
- Date: 2026-09-17
- Subject: /Users/sac/ash_a2a
- Pinned SHA: `02d8616f72014453808f3e09dbc8a2ca9b6877dc` — **HEAD MOVED**: observed `801374a9642c45e6e4299056bac92e5f29e2961e` (branch `main`, clean tree, ahead of origin 111). `02d8616` verified ancestor (3 commits: 5cd185f hddl reconcile, 1962b8f merge, 801374a changelog docs; only test fixtures + CHANGELOG changed, no lib code). **Re-pinned: verification proceeds at `801374a`.**
- Standing: **in-progress** (court running)
- Note: this receipt supersedes a partial receipt left by the usage-limit-killed first spawn at this path; every claim re-verified fresh in this session.

## Court (repo-defined, .github/workflows/ci.yml)

ci.yml steps: deps.get → `mix format --check-formatted` → `mix compile --warnings-as-errors` (default dev env; test/support NOT on dev elixirc path, mix.exs:51-52) → `mix test` (real Postgres :55432 per ci.yml:22-30; native HDDL CLI per ci.yml:57-58 — prebuilt at `native/hddl_cli/target/release/hddl_cli`). `bin/ci-local.sh` (act) is repo-disclosed as unable to complete on this machine class, so the direct command sequence is the local court. Postgres :55432 confirmed reachable pre-run.

## Commands + exit codes

| command | exit |
|---|---|
| `git rev-parse HEAD` | 0 → `02d8616f72014453808f3e09dbc8a2ca9b6877dc`, clean |
| `mix deps.get` | 0 ("All dependencies have been fetched"; advisory notices only) |
| `mix format --check-formatted` | 0 |
| `MIX_ENV=test mix compile --force --warnings-as-errors` | **1** — FAILED (stricter-than-court invocation; see falsifiers) |
| `MIX_ENV=dev mix compile --force --warnings-as-errors` (the court's compile gate) | 0 (287 files, clean) |
| `mix test` | (running) |

## Capability evidence (orchestration surface — owns predicate: REAL, not aspirational)

Orchestration loop machinery (Orient → decompose → episodes → certify analogues), all at pinned SHA:

- HDDL planning/decomposition: `lib/ash_a2a/planning.ex:32` (`AshA2A.Planning` — "Planners may propose PDDL/HDDL/FOND/HTN/temporal candidates", candidate-only standing); `lib/ash_a2a/planning/hddl_solver.ex:1`; `lib/ash_a2a/planning/hddl_deterministic_synthesis.ex:1`; `lib/ash_a2a/planning/hddl_renderer.ex`; `lib/ash_a2a/hddl_operator.ex`; native ferroplan-backed CLI `native/hddl_cli/` (built release binary present).
- Episode executor (bounded orchestration loop): `lib/ash_a2a/semantic/episode.ex:1` — terminal conditions `completed | quiescent | refused | resource_exhausted | bound_reached`, "no unbounded path", composes `BoundedProduction`/`Bounds`/`Allocator`/`CommandBus`.
- Agent card: `lib/ash_a2a/info.ex:75-76` (`agent_card/2` → `A2A.AgentCard.t()`); `lib/ash_a2a/capability_index/agent_card_builder.ex:13-14` (`build_agent_card/2` builds real `%A2A.AgentCard{}`).
- A2A protocol dispatch: `lib/ash_a2a/dispatcher.ex:127` (`dispatch/3`); supervised agent process `lib/ash_a2a/agent.ex:1`; consequence boundary `lib/ash_a2a/command_bus.ex:1`.
- Admission + SA2A transport: `lib/ash_a2a/semantic/admission.ex:1,43` (`admit/2`); `lib/ash_a2a/semantic/admission_pipeline.ex:1`; SA2A admission state machine `lib/ash_a2a/sa2a/state_machine.ex:1` (RFC S41 prefix `RECEIVED -> PARSED -> IDENTIFIED -> STRUCTURALLY_VALID -> ... -> ADMITTED`); SA2A conformance court `lib/ash_a2a/sa2a/conformance.ex:1` (two-runtime WASM portability receipt, fail-closed `computed: false` rule); mix task `lib/mix/tasks/ash_a2a.sa2a_conformance.ex:1`.
- HTTP transport: `A2A.Plug`/`A2A.Plug.Auth` (plug dep, mix.exs:98-104) with real HTTP pipeline test `test/ash_a2a_plug_agent_card_test.exs`.

## FOND classification

(pending `mix test`)

## Falsifiers attempted

1. Stricter-than-court compile: `MIX_ENV=test mix compile --force --warnings-as-errors` → exit 1. Two test-support fixture domains — `AshA2A.Test.Fixture.StreamItemDomain` (`test/support/cancel_fixture.ex:53`) and `AshA2A.Test.Fixture.AuthProbeDomain` (`test/support/auth_plug_fixture.ex:42`) — omit the repo's own documented opt-out `validate_config_inclusion?: false` (established pattern, e.g. `test/support/fixture.ex:393-397`), so Ash emits domain-config-inclusion warnings that fail only under a warnings-as-errors bar the repo's court never applies to the test env (CI compiles dev only, ci.yml:74). LATENT defect, not a court failure — no repair (repair sanctioned only for build-broken; repo court passes). Escalating to integrator.

## What the operator did NOT have to write

(pending)
