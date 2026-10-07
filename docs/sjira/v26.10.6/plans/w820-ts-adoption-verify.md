# W820 — ash_typescript adoption-doc verification receipt

Date: 2026-10-07. Repo: /Users/sac/xaas, branch `feat/playwright-surface` (HEAD `a0723bf6`).
Subject: `docs/claude/diataxis/explanation/ash-typescript-adoption.md` verified and
corrected against the W813-era tree. No W813 receipt file is landed in
`docs/sjira/v26.10.6/plans/` (no `w813*` entry), so verification used the router,
config, tests, and audit source directly.

## Per-claim disposition

| Doc claim | Status | Evidence |
|---|---|---|
| `{:ash_typescript, "~> 0.17"}` in mix.exs | VERIFIED | `mix.exs:137` |
| 3-resource adoption (Subscription/Provider/Org) | VERIFIED (still true, no longer exhaustive) | `typescript_rpc` blocks: `lib/xaas/billing.ex:10`, `lib/xaas/marketplace.ex:14`, `lib/xaas/accounts.ex:10` |
| config block incl. camel_case formatters | VERIFIED | `config/config.exs:179-185` |
| "no live /rpc/run endpoint mounted" | CORRECTED (stale) | `lib/xaas_web/router.ex:101-102` mount `POST /internal-api/rpc/run` + `rpc/validate` via `XaasWeb.AshTypescriptRpcController` (`lib/xaas_web/controllers/ash_typescript_rpc_controller.ex:14,19` → `AshTypescript.Rpc.run_action/validate_action`) |
| generated functions reference a path nothing serves | CORRECTED (stale) | same router mount + real HTTP courts `test/xaas_web/rpc_surface_deepening_test.exs:40,49` |
| `--run-endpoint`/`--validate-endpoint` required-in-practice flags | CORRECTED (superseded) | endpoints now pinned in `config/config.exs:182-183`; flags no longer required |
| ash_types.ts 664 / ash_rpc.ts 359 lines | CORRECTED (stale counts) | real `wc -l`: 939 / 400 at v26.10.6 (2026-09-27 mtimes; both non-empty) |
| grep excerpt line numbers 192/267/342 | CORRECTED (stale) | current: 193/268/343 plus new 84 (`executeActionRpcRequest`), 380 (`measureProject`) |
| 3 resources = whole rollout | CORRECTED | 4 domains now wired: 4th is `Xaas.Operations` (`lib/xaas/operations.ex:22-26`, `rpc_action(:measure_project, :measure)` on `Xaas.Operations.ProjectMeasure.Measurement`) — a mutating (:measure) rpc action now exists, superseding the doc's "no mutating RPC action exposed" blanket claim |
| Ledger/User/Token untouched | VERIFIED | no `typescript_rpc` or `AshTypescript.Resource` in `lib/xaas/ledger/*`, `lib/xaas/accounts/user.ex`, `token.ex` (grep over `lib/`) |

## Status block added

"Status at v26.10.6" section added to the doc with: generated artifact locations
(`assets/js/ash_rpc.ts` 400 lines, `assets/js/ash_types.ts` 939 lines), route paths
(`POST /internal-api/rpc/run|validate`, token-gated `/internal-api` scope), domain
coverage table (4 domains, 4 rpc actions, file:line each), courts
(`test/xaas_web/rpc_surface_deepening_test.exs`), release_audit pinning
(`check_rpc_alignment/1`, `lib/mix/tasks/xaas.release_audit.ex:313-349`, W636 repoint),
and the 0.18-era mandatory `manifest: Xaas.AshTypescriptManifest`
(`config/config.exs:186-187`).

Note: the task brief said "5 domains wired"; the tree shows **4**. Recorded as 4
(facts only).

## Verification performed

- `grep -rn "rpc" lib/xaas_web/router.ex` → lines 101-102.
- `grep -rln "AshTypescript.Rpc" lib/` + `grep -n rpc_action lib/xaas/*.ex` → 4 domains.
- `wc -l` on both generated files; `grep -c "export async function"` → 5 exports.
- `sed -n '300,345p' lib/mix/tasks/xaas.release_audit.ex` → check_rpc_alignment pins.
- Cited line numbers re-checked on disk (`grep -n` config.exs/mix.exs).

## Standing

PARTIAL_ALIVE. The doc now matches the tree for routes, config, artifacts, audit
pinning, and domain coverage. Not executed: `mix ash_typescript.codegen` rerun and
the rpc court suite were not run this lane (no build root, disk-constrained); the
generated files' mtimes (2026-09-27) postdate the last recorded codegen, so artifact
staleness vs. current resource schemas is UNKNOWN. Line counts and route/config facts
are exact-tree verified.
