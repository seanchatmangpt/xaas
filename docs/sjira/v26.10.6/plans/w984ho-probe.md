# W984ho — unclaimed-family probe: AshTypescript RPC surface (branch level)

Lane W984ho · branch `feat/playwright-surface` · 2026-10-07 · no commit (per dispatch)

## Subject

`XaasWeb.AshTypescriptRpcController`
(`/Users/sac/xaas/lib/xaas_web/controllers/ash_typescript_rpc_controller.ex`),
mounted at POST `/internal-api/rpc/run` and `/rpc/validate`
(`/Users/sac/xaas/lib/xaas_web/router.ex:109-110`), behind
`RequireInternalApiToken`. Downstream: `AshTypescript.Rpc.run_action/
validate_action` (ash_typescript 0.18.2), generated TS client
`assets/js/ash_rpc.ts` (400 lines) / `assets/js/ash_types.ts` (939 lines).

## Per-module dispositions

| Module / surface | Disposition |
|---|---|
| `AshTypescriptRpcController.run/2` happy path, no-actor scoping, validate bad-input, unknown action, missing action param, 401/503 auth floor, determinism, router repoint | **COVERED** — pre-existing `test/xaas_web/rpc_surface_deepening_test.exs` (W813) |
| `assets/js/ash_rpc.ts` / `ash_types.ts` generated client | **INDIRECT** — structure asserted via `test/xaas/ash_typescript_manifest_test.exs` (W984dq manifest court) + generated-artifact doctrine; no direct HTTP-level test of the .ts files themselves |
| GET on the POST-only RPC routes | **UNCOVERED → now courted** — falls through to the `forward "/internal-api"` catch-all (AshJsonApi.Router), whose `:internal_api` pipeline (accepts `json-api` only) raises `Phoenix.NotAcceptableError` for `application/json`. Pinned. |
| Malformed JSON body | **UNCOVERED → now courted** — `Plug.Parsers.ParseError` raised at the endpoint boundary before the router; never a 200 RPC envelope. Pinned. |
| rpc/validate unknown action | **UNCOVERED → now courted** — typed `action_not_found` envelope; validate branch parity with run. Pinned. |
| rpc/validate success envelope (`success=true`) | **UNCOVERED → now courted** — positive validate branch. Pinned. |
| Non-list `fields` cast failure on rpc/run | **UNCOVERED → now courted** — typed `success=false` envelope (contract holds). |
| Non-list `fields` cast failure on rpc/validate | **UNCOVERED → now courted — DEFECT FOUND** |

## Finding: run/validate cast-failure asymmetry (500-class)

`rpc/run` with `"fields": 42` returns the typed `success=false` envelope.
`rpc/validate` with the identical body raises an unhandled
`FunctionClauseError` in
`AshTypescript.Rpc.FieldProcessing.Atomizer.atomize_requested_fields/3`
(guard `is_list(requested_fields)`, ash_typescript 0.18.2,
`deps/ash_typescript/lib/ash_typescript/rpc/field_processing/atomizer.ex:43`
via `pipeline.ex:107` → `rpc.ex:705` → controller `validate/2`) — a 500 in
production. The generated TS client's validate step can 500 on inputs the
run path itself refuses with a typed error. Upstream-shaped defect, surfaced
at the branch level; court pins the real current behavior with
`assert_raise FunctionClauseError` so any dependency upgrade that fixes (or
further breaks) the asymmetry must update this file.

## Court

`/Users/sac/xaas/test/xaas_web/rpc/family_court_w984ho_test.exs` — 7 tests,
real ConnCase HTTP through the real router, real token convention, real
sandboxed Postgres, zero mocks, mutation rationale per test.

## Verification (real output)

```
MIX_BUILD_ROOT=_build-laneW984ho mix test test/xaas_web/rpc/family_court_w984ho_test.exs
→ 7 passed, exit 0
mock gate scan_mock_usage(["test","lib"]) → []
```

## Lane hygiene

Only files touched: the new test file and this receipt (git status checked —
no overlap with other lanes' modified files). During the run another lane's
in-flight edit (`lib/xaas/operations/authority_ledger_export.ex`, not mine)
briefly broke the shared compile ("unexpected reserved word: end"); per the
compile-freeze SLA I did not touch it — it self-healed ~90s later and the
court then passed. Lane build root `_build-laneW984ho` deleted at
integration.
