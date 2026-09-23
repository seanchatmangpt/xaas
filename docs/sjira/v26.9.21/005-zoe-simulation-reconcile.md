---
{
  "identity": "SJ-005",
  "title": "Reconcile the two ZOE event simulations",
  "description": "Two independent implementations landed from parallel branches: Xaas.Zoe.EventSimulation (dfcm, whole-event obligations) and Xaas.Zoe.EventSimulationZoe (agent contract/0 + simulate/2). Only the latter backs XaasWeb.A2A.ZoeEventSimulationAgent. Merge into one module preserving both test suites' assertions.",
  "subject": "zoe-simulation-reconcile",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "ALIVE",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-005",
  "required_courts": [
    "compile",
    "tests",
    "chicago_no_mocks"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "single Xaas.Zoe.EventSimulation module",
    "both test files' assertions pass against it (test/xaas/zoe/*, test/xaas_web/a2a/zoe_event_simulation_agent_test.exs)"
  ],
  "falsifiers": [
    "either suite loses an assertion during the merge"
  ],
  "projections": [
    "jira",
    "verification",
    "receipt"
  ],
  "dependencies": [],
  "authority_requirement": "NONE",
  "path_scope": [
    "lib/xaas/zoe/**",
    "lib/xaas_web/a2a/**",
    "test/xaas/zoe/**",
    "test/xaas_web/a2a/**"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-005: Reconcile the two ZOE event simulations

- **Standing**: ALIVE

## Status
ALIVE — subject already merged in worktree `sjira/sj-005` (commit `d95eed2`,
prior session) and re-verified for real in this session on the worktree
(never on `/Users/sac/xaas` main checkout).

- **Repository**: seanchatmangpt/xaas @ `8e72cfc` (worktree HEAD:
  `d95eed2959914ef6b90bbc7a1ecdc828e2a6fce4`, branch `sjira/sj-005`)

## Description
Two independent implementations landed from parallel branches: Xaas.Zoe.EventSimulation (dfcm, whole-event obligations) and Xaas.Zoe.EventSimulationZoe (agent contract/0 + simulate/2). Only the latter backs XaasWeb.A2A.ZoeEventSimulationAgent. Merge into one module preserving both test suites' assertions.

## Evidence
- `lib/xaas/zoe/event_simulation.ex` — single merged module. `simulate/2`
  dispatches on `contract_version`: absent → whole-event timeline surface
  (`simulate_event/2`, unchanged from the original DfCM implementation);
  present (`"zoe-event-ops/v1"`) → contract-snapshot surface
  (`simulate_snapshot/2`, unchanged from the original
  `EventSimulationZoe` implementation, including `contract/0` and
  `digest/1`). The one helper-name collision (`observations/1`) was
  resolved by renaming the snapshot side to `snapshot_observations/1`.
- `lib/xaas/zoe/event_simulation_zoe.ex` — file removed; no longer present
  in the worktree.
- `lib/xaas_web/a2a/zoe_event_simulation_agent.ex` — calls
  `Xaas.Zoe.EventSimulation` (not `EventSimulationZoe`) for both
  `contract/0` and `simulate/2`.
- `grep -rln "EventSimulationZoe" lib test` in the worktree returns only
  `test/xaas/zoe/event_simulation_zoe_test.exs` (the test module's own
  filename/id; its `alias Xaas.Zoe.EventSimulation` already targets the
  merged module) — no other file references the old module name.

## Definition of done
- [x] single Xaas.Zoe.EventSimulation module
- [x] both test files' assertions pass against it (test/xaas/zoe/*, test/xaas_web/a2a/zoe_event_simulation_agent_test.exs)

Runnable check (run from the `sjira/sj-005` worktree, not
`~/xaas` main checkout — the ticket's original `cd ~/xaas` invocation hits an
unrelated pre-existing `bcrypt_elixir`/Elixir-1.19.5 dep-compile break in the
main checkout that does not exist in this worktree's `_build`):

```sh
cd /Users/sac/xaas/worktrees/sjira/sj-005 && mix test test/xaas/zoe test/xaas_web/a2a
# => Finished in 1.1 seconds
#    21 tests, 0 failures
#    EXIT: 0
```

Also re-verified this session:

```sh
cd /Users/sac/xaas/worktrees/sjira/sj-005 && mix compile --warnings-as-errors --force
# => Generated xaas app; EXIT: 0
```

```sh
cd /Users/sac/xaas/worktrees/sjira/sj-005 && mix format --check-formatted \
  lib/xaas/zoe/event_simulation.ex lib/xaas_web/a2a/zoe_event_simulation_agent.ex \
  test/xaas/zoe/event_simulation_zoe_test.exs test/xaas/zoe/event_simulation_test.exs \
  test/xaas_web/a2a/zoe_event_simulation_agent_test.exs
# => EXIT: 0 (formatted)
```

## Generation vs hand-written
No ggen pack, RDF ontology, or SPARQL template under `priv/packs/`,
`priv/ggen_igniter/`, or any other `priv/*` ontology dir targets ZOE event
simulation reconciliation (`find priv -iname "*zoe*"` returns no matches;
`priv/packs/` holds `xaas_ocel_envelope_pack`, `xaas_library_pack`,
`xaas_telemetry_pack`, `xaas_ultracode_pack`, `xaas_frontier_release_pack` —
none cover this domain). This merge is a structural consolidation of two
hand-written, event-specific simulation algorithms (obligation-emission
rules over an observation timeline vs. a capability trace over a Planning
Center contract snapshot) with no ontology/schema projection behind either
surface. Flagged **UNSUPPORTED(generator-capability)**: no generator exists
for this domain-specific simulation logic, so the merge itself was
necessarily hand-written (done in a prior session, commit `d95eed2`); this
session's contribution is real re-verification only, no new hand-written
code.

## Falsifiers
- either suite loses an assertion during the merge — not observed: 21/21
  tests pass (`test/xaas/zoe/event_simulation_test.exs`,
  `test/xaas/zoe/event_simulation_zoe_test.exs`,
  `test/xaas_web/a2a/zoe_event_simulation_agent_test.exs` plus sibling a2a
  tests in the same run)
