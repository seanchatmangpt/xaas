# W984fg — unclaimed-family probe: lib/xaas/runtime/

Lane: W984fg · Date: 2026-10-07 · Branch: feat/playwright-surface (no commit)
Build root: `_build-laneW984fg`

## Sibling-lane exclusions (verified disjoint)
- `Xaas.Runtime.ProviderRegistry` — W984dq8's lane. Their untracked
  `test/xaas/runtime/provider_registry_deepening_test.exs` is present in the tree; I did not
  touch it and my court exercises the registry only as a real collaborator of Reconciler.
- `provider_fabric` CapabilitySet/FailureSet NOT_STATE_BEARING (W650h21) — verified by reading
  `capability_set.ex` / `failure_set.ex`: pure data functions, no GenServer/ETS. Gone past both.

## Per-module disposition (73 modules total under lib/xaas/runtime/)

Method: per-module CamelCase last-segment grep against test/, then reading every hit and the
source of all state-bearing files.

### Top level (5 modules)
| module | kind | test refs | disposition |
|---|---|---|---|
| Xaas.Runtime.Supervisor | Supervisor (rest_for_one) | 0 direct | was UNCOVERED → COVERED_BY_W984FG |
| Xaas.Runtime.Reconciler | GenServer probe loop | 0 direct | was UNCOVERED → COVERED_BY_W984FG |
| Xaas.Runtime.ProviderRegistry | GenServer circuit-breaker registry | W984dq8 deepening test | SIBLING_LANE (W984dq8) |
| Xaas.Runtime.Provider | struct/attrs module | broad (actuation, EU AI Act, controllers) | COVERED (indirect, wide) |
| Xaas.Runtime.Router | dispatcher | test/xaas/runtime/router_test.exs | COVERED (direct) |

### fond/ (31 modules)
29 modules have direct per-module test files under `test/xaas/runtime/fond/` (executor,
idempotency, reconciler, selector, runtime, lease, queue, health, recovery, planner, backoff,
graph, outcome, trace, circuit, transition, exclusion, policy, edge, deadline, …). The two gaps:

| module | kind | disposition |
|---|---|---|
| fond/registry.ex — Xaas.Runtime.FOND.Registry | GenServer map store | was UNCOVERED → COVERED_BY_W984FG |
| fond/supervisor.ex — Xaas.Runtime.FOND.Supervisor | empty one_for_one tree | was UNCOVERED → COVERED_BY_W984FG |

### provider_fabric/ (36 modules)
Every module has a direct per-module test file under `test/xaas/runtime/provider_fabric/`
(adapter, idempotency, budget?, health, failure_set, selector, transition, graph, telemetry,
outcome, policy, backoff, priority, queue, attempt, planner, trace, edge, recovery, circuit,
reconciler, weighted, provider, lease, deadline, router, scheduler, state, capability_set,
receipt). CapabilitySet/FailureSet confirmed pure (W650h21 type holds). COVERED (direct).

## Court
`test/xaas/runtime/family_court_w984fg_test.exs` — 11 tests, real GenServers/Supervisors under
the ExUnit test supervisor, zero mocks. Mutation rationale per test in the moduledoc.

1–7. `Xaas.Runtime.Reconciler` probe loop: all four health-outcome branches exercised —
   `:healthy` → `:ok` reset; `:degraded` → degraded mid-state; raising health →
   `{:unavailable, {kind, reason}}`; `{:unavailable, reason}` return; non-contract return →
   `{:error, {:invalid_health, other}}`; multi-provider single-pass iteration; self-rescheduling
   loop accumulating failures 1→2→3 into `:open`.
8. `Xaas.Runtime.Supervisor`: rest_for_one tree starts ProviderRegistry + Reconciler, both
   verified alive via `which_children`.
9. `Xaas.Runtime.FOND.Supervisor`: starts with empty one_for_one child list.
10–11. `Xaas.Runtime.FOND.Registry`: register/all, duplicate-id overwrite semantics, state
   preserved across `:all` calls.

## Gates (real output, this session)
- Court: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984fg mix test
  test/xaas/runtime/family_court_w984fg_test.exs` → **11 passed, exit 0** (cold lane build root,
  full dep compile succeeded, 426M).
- Mock gate: `scan_mock_usage(["test", "lib"])` → **[]** (exit 0).

## Standing: ALIVE
## Open falsifiers: full lane-wide `mix test` not run (out of lane budget); only the court file
and mock gate were executed under `_build-laneW984fg`.
## Lane cleanup: `rm -rf _build-laneW984fg` DENIED by session permission gate (PreToolUse
refusal, 2026-10-07). Build root (426M) left on disk — coordinator cleanup per
[[same-checkout-fanout]] cleanup law.
