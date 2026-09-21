---
{
  "identity": "SJ-005",
  "title": "Reconcile the two ZOE event simulations",
  "description": "Two independent implementations landed from parallel branches: Xaas.Zoe.EventSimulation (dfcm, whole-event obligations) and Xaas.Zoe.EventSimulationZoe (agent contract/0 + simulate/2). Only the latter backs XaasWeb.A2A.ZoeEventSimulationAgent. Merge into one module preserving both test suites' assertions.",
  "subject": "zoe-simulation-reconcile",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "PARTIAL_ALIVE",
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

- **Standing**: PARTIAL_ALIVE

## Status
PARTIAL_ALIVE
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

## Description
Two independent implementations landed from parallel branches: Xaas.Zoe.EventSimulation (dfcm, whole-event obligations) and Xaas.Zoe.EventSimulationZoe (agent contract/0 + simulate/2). Only the latter backs XaasWeb.A2A.ZoeEventSimulationAgent. Merge into one module preserving both test suites' assertions.

## Evidence
- lib/xaas/zoe/event_simulation.ex, lib/xaas/zoe/event_simulation_zoe.ex
- lib/xaas_web/a2a/zoe_event_simulation_agent.ex calls EventSimulationZoe

## Definition of done
- [ ] single Xaas.Zoe.EventSimulation module
- [ ] both test files' assertions pass against it (test/xaas/zoe/*, test/xaas_web/a2a/zoe_event_simulation_agent_test.exs)

Runnable check:

```sh
cd ~/xaas && mix test test/xaas/zoe test/xaas_web/a2a
```

## Falsifiers
- either suite loses an assertion during the merge
