# W984lj — Application supervision-tree court (probe receipt)

- Subject: `Xaas.Application` supervision tree, `/Users/sac/xaas` @
  `feat/playwright-surface` (branch state as of 2026-10-08, no commit —
  lane deliverables left uncommitted per dispatch).
- Court: `test/xaas/application_supervision_court_w984lj_test.exs` — 7 tests,
  all pass, exit 0.
- Gate: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984lj
  mix test test/xaas/application_supervision_court_w984lj_test.exs` → `exit=0`,
  `Result: 7 passed`. Cold-lane full compile; runs ~0.05s once warm.
- Mock gate: `scan_mock_usage(["test","lib"])` → `[]` (exit 0).

## Contract witnessed (REAL `Supervisor.which_children(Xaas.Supervisor)`, test env)

17 unconditional children + 1 conditional. Source declaration order
(recovered as `Enum.reverse(which_children)` — this OTP reports reverse start
order; observed empirically and pinned in the court):

Endpoint, PromEx, DNSCluster, Telemetry, LegacyRepo, Repo, Oban, Vault,
Hammer, Phoenix.PubSub (child id `Phoenix.PubSub.Supervisor`), Finch
(child id `Xaas.Finch`), Ultracode TaskSupervisor, ProviderRecovery,
NextReadUserAgent, NextReadAshAgent, ZoeEventSimulationAgent, PPlan durable
ETS store (child id `AshPPlan.Reactor.Durable.Store.Ets`, not the `:name`
option value `Xaas.Bridges.PPlan.Store`).

- Strategy: `:one_for_one` (asserted via `:sys.get_state` elem 2; the state is
  a tuple, not a map, on this OTP).
- Order-dependency asserted: LegacyRepo < Repo < Oban in declaration order.
- Conditional gate: only `Xaas.Sa2a.Bridge`, gated on
  `System.find_executable("autofde")` via `available?/0`; on this host it is
  ABSENT (logged at boot, no bridge child). Court asserts tree == gate.
- Types observed (and now asserted): supervisors — Endpoint, PromEx, Telemetry,
  LegacyRepo, Repo, Oban, PubSub, Ultracode TaskSupervisor. Workers —
  DNSCluster, Vault, Hammer, Finch, ProviderRecovery, 3 A2A agents, PPlan store.

## Test-env deltas vs source/dev (documented, asserted as test-env contract)

- Oban runs `testing: :manual` bound to `Xaas.Repo`; the running config has
  `plugins: []` and `queues: []` — the AshOban-merged Cron plugin exists only
  in the child spec, not in the test-env runtime config. Court asserts
  repo + `:manual`, not the crontab.
- PromEx dashboard upload fails on this lane (Grafana nxdomain) — pre-existing
  dev-substrate noise, unrelated to the tree contract.
- `os_mon` shutdown noise at exit — pre-existing, unrelated.

## Mutations the court kills (rationale per test)

1. supervisor rename → whereis assert; 2. child removal → 17-id set assert;
3. reorder (Repo/Oban swap) → declaration-order assert; 4. gate flip
(hardcode bridge in/out) → gate-consistency assert; 5. type change (worker↔
supervisor child shape) → per-id type asserts; 6. strategy change → one_for_one
assert; 7. Oban rewire off Xaas.Repo / out of :manual → Oban wiring assert.

## Iterations (disclosed)

First green run took 5 fix rounds against the real tree: chained comparison
`a < b < c` bug (parses as `(a<b)<c`), wrong assumed child ids (`Finch`,
`Xaas.Bridges.PPlan.Store`), assumed types (Finch/DNSCluster workers not
supervisors, Endpoint/PromEx/Telemetry/Repos supervisors), and which_children
reverse order. All corrected to observed truth; no expectations were weakened
to pass — they were corrected to the real tree, and each assert still pins a
distinct source mutation.

## Standing: ALIVE (court passes on the exact lane subject; no commit per dispatch)

- Cleanup: `rm -rf /Users/sac/xaas/_build-laneW984lj` attempted post-receipt.
