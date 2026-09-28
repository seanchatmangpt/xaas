# v26.9.27 two-port runtime enforcement — lane map

One canonical checkout (`/Users/sac/xaas`, branch `v26.9.27/closure-runtime`). No worktrees,
no shadow repos, no agent git. Coordinator owns every git transition.

Shared contract artifact (coordinator-authored, read-only to lanes):
`priv/ultracode/runtime_surface.json`.

## Off-limits (another executor has uncommitted in-flight edits)

`lib/xaas/ultracode/{dispatch,wave_loop,provider_registry,autonomic,provider_recovery,
self_digest_worker}.ex`, `lib/xaas/ultracode/capability_resolver.ex`,
`lib/xaas/ultracode/capability_resolver/**`, `lib/xaas/ultracode/capital_census/**`,
`config/*.exs`, `lib/xaas/application.ex`, `lib/mix/tasks/xaas.self_digest.ex`.
`dispatch.ex` env wiring is a coordinator-only, post-wave single edit.

## Lanes

| lane | owns | build root |
|---|---|---|
| L1 surface | `lib/xaas/ultracode/runtime_surface.ex`, `lib/xaas/ultracode/runtime_surface/failure.ex`, `test/xaas/ultracode/runtime_surface_test.exs` | `_build-lane1` |
| L2 worker env | `lib/xaas/ultracode/worker_env.ex`, `test/xaas/ultracode/worker_env_test.exs` | `_build-lane2` |
| L6 gate | `priv/zcode_plugin/marketplace/xaas-fabric/scripts/xaas-gate.mjs`, `test/xaas/ultracode/gate_surface_test.exs` | `_build-lane6` |
| L3 capability port | `lib/xaas/ultracode/capability_port.ex`, `test/xaas/ultracode/capability_port_test.exs` | `_build-lane3` |
| L4 lease | `lib/xaas/ultracode/lease.ex`, `test/xaas/ultracode/lease_surface_test.exs` | `_build-lane4` |
| L5 fabric + e2e | `lib/xaas_web/controllers/execution_fabric_controller.ex`, `test/xaas_web/controllers/execution_fabric_surface_test.exs`, `test/xaas/ultracode/two_port_e2e_test.exs` | `_build-lane5` |

Waves: {L1, L2, L6} → {L3, L4} → {L5} → audit + adversarial courts → coordinator integration.
