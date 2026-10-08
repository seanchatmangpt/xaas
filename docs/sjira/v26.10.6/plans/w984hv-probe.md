# W984hv — truth-pass: docs/claude/diataxis/explanation/ash-typescript-adoption.md

Date: 2026-10-07. Lane W984hv, shared canonical checkout `/Users/sac/xaas`, branch
`feat/playwright-surface`. Docs-only: no commit, no build root, no branch switch, no stash.
Sibling-modified file: read disk state, appended only, no sibling edits reverted.

## Before

The doc already carried a "Status at v26.10.6" verified block (W820 lane) whose substantive
claims were: dep `{:ash_typescript, "~> 0.17"}` in mix.exs; config block in
`config/config.exs` incl. `run_endpoint`/`validate_endpoint` + mandatory 0.18-era
`manifest:`; routes `POST /internal-api/rpc/run` and `POST /internal-api/rpc/validate`
inside the token-gated `/internal-api` scope served by `XaasWeb.AshTypescriptRpcController`;
4-domain / 4-rpc-action table; generated `assets/js/ash_rpc.ts` (400 lines) +
`assets/js/ash_types.ts` (939 lines); court `test/xaas_web/rpc_surface_deepening_test.exs`;
`check_rpc_alignment/1` in `mix xaas.release_audit`.

Excerpt of the block's citations (before):

> **RPC routes** (`lib/xaas_web/router.ex:101-102`, ... `XaasWeb.AshTypescriptRpcController`
> delegating to `AshTypescript.Rpc.run_action/validate_action`):
> ...
> The generated clients target these paths via `config/config.exs:182-183`
> ...
> **Dependency**: `{:ash_typescript, "~> 0.17"}` (`mix.exs:137`); config requires the
> 0.18-era mandatory `manifest:` module (`config/config.exs:186-187`).
> **release_audit pinning**: `check_rpc_alignment/1` (`lib/mix/tasks/xaas.release_audit.ex:313-349`)

## What was verified (commands + real output)

- `grep -n 'rpc/run|rpc/validate' lib/xaas_web/router.ex` →
  `109: post("/rpc/run", AshTypescriptRpcController, :run)`,
  `110: post("/rpc/validate", AshTypescriptRpcController, :validate)`; confirmed inside
  `scope "/internal-api", XaasWeb do pipe_through([:api, :require_internal_api_token])`
  (router.ex:96-98). Doc cited 101-102 — drifted.
- `grep -n run_endpoint config/config.exs` → `180:` / `181:`;
  `manifest: Xaas.AshTypescriptManifest` at `185:` (0.18 mandatory-manifest comment at 184).
  Doc cited 182-183 / 186-187 — drifted.
- `grep -n ash_typescript mix.exs` → `153: {:ash_typescript, "~> 0.17"}`. Doc cited 137 — drifted.
- `grep -n check_rpc_alignment lib/mix/tasks/xaas.release_audit.ex` → definition at `596`
  (pipeline arm at `97`). Doc cited 313-349 — drifted. Behavior re-read: fails-closed on
  both canonical endpoint strings in config and both controller mounts in router; typed
  enoent findings, no raise.
- `wc -l assets/js/ash_rpc.ts assets/js/ash_types.ts` → `400` / `939` — exact match.
- `grep -n "export async function" assets/js/ash_rpc.ts` → all 4 exports:
  `listAccountsOrgs` :193, `listBillingSubscriptions` :268, `listMarketplaceProviders`
  :343, `measureProject` :380.
- Domain table re-grepped: accounts.ex:10-14, billing.ex:10-14, marketplace.ex:14-18,
  operations.ex:21-25 (`:measure_project, :measure` — a `bypass action(:measure)` generic,
  not a plain `:read`).
- Resource extensions: `AshTypescript.Resource` at subscription.ex:110, provider.ex:22,
  org.ex:79, project_measure/measurement.ex:21; `AshTypescript.Rpc` in operations.ex:7 and
  the other three domains.
- Court: `test/xaas_web/rpc_surface_deepening_test.exs` exists, real ConnCase over the real
  router + sandboxed Postgres, docstring enumerates 6 cases (success envelope, typed
  validation, unknown action, W723 auth floor, W636 repoint, determinism), `@token
  System.fetch_env!("INTERNAL_API_TOKEN")` — no mocks.
- Controller: `lib/xaas_web/controllers/ash_typescript_rpc_controller.ex` present.
- GraphQL cross-check (W984et excision trail
  `docs/sjira/v26.10.6/plans/w984et-probe.md`): doc makes no "typescript replaces graphql"
  claim; graphql excised repo-wide; only live graphql-adjacent surface is
  `lib/xaas/semantics/vkg.ex graphql/2` via ash_r2rml — unrelated to ash_typescript.
- `w984ho` probe receipt: `ls docs/sjira/v26.10.6/plans/w984ho*` → no matches. Absent on
  disk; noted in the doc's verified block rather than fabricated.

## Corrections applied

Append-only dated section "Verified 2026-10-07 (W984hv truth-pass)" added to the doc,
listing the four drifted line-number citations with corrected values and the
confirmed-unchanged inventory (artifact counts, 4 RPC exports, domain table, extensions,
court reality, controller, graphql status, w984ho absence). No prior sibling content
edited or reverted.

## After

Doc now carries two verification strata: the existing "Status at v26.10.6" block plus the
new "Verified 2026-10-07 (W984hv truth-pass)" block correcting router.ex:109-110,
config.exs:180-181/185, mix.exs:153, release_audit.ex:596.

Standing: ALIVE (docs truth-pass; every substantive claim code-verified on the exact
working tree; only stale line citations corrected). Falsifier for this pass: any claim in
the new verified block not reproducible by the greps above.
