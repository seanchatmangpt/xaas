# W301 — env isolation, execution_fabric_controller_test.exs — FINAL RECEIPT

Date: 2026-10-06 · Lane: W301 (integration, v26.10.6 convergence) · Repo: /Users/sac/xaas · Branch: feat/playwright-surface

## Identity (exact subject)

- File owned+modified: `test/xaas_web/execution_fabric_controller_test.exs` (only file changed)
- Plug inspected, NOT modified: `lib/xaas_web/plugs/require_internal_api_token.ex`
  - Read-first check (lane rule): the plug reads **`System.get_env("INTERNAL_API_TOKEN")` only**
    (lines 95, 103). No Application-env fallback, no dual source. Therefore the plug is NOT
    owned by this lane and was not touched.

## Problem (W251 dominant class, 245/247)

`execution_fabric_controller_test.exs:180` `System.delete_env("INTERNAL_API_TOKEN")`
(restored `:188`) mutates VM-global env. Even though this module is not `async: true`,
other files' async tests run concurrently in the same VM and observe the deletion window,
crashing on `System.fetch_env!` (measured in W251: 87 EnvError + 6 503-misfire + 9
401-vs-503).

## Fix (what changed)

The env-deleting test was replaced, not patched. "unset INTERNAL_API_TOKEN rejects every
request with 503" now proves the same fail-closed invariant in a **real subprocess** whose
environment genuinely lacks `INTERNAL_API_TOKEN` (via `System.cmd` with
`env: %{"INTERNAL_API_TOKEN" => nil}`), loading the exact same compiled plug modules from
`_build/test/lib/*/ebin` (repeated `-pa` per path) and dispatching a real `Plug.Test.conn`
through `XaasWeb.Plugs.RequireInternalApiToken.call/2`. Asserts on real subprocess output:
`status: 503`, `halted: true`, body contains `internal_api_misconfigured`, exit 0.

Notes encoded in the test comment: zero global mutation, window cannot leak; repeated
`-pa path` is required (single `-pa` followed by a glob collapses to "one flag + script
names", yielding `No file named ...`); `Application.ensure_all_started(:phoenix)` is
started in the subprocess because the plug's 503 path renders via `Phoenix.Controller.json/2`.

## Verification (real output, pinned toolchain)

1. File alone:
   `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token MIX_ENV=test mix test test/xaas_web/execution_fabric_controller_test.exs`
   → `Result: 48 passed`
2. Poisoning check (paired):
   `... mix test test/xaas_web/execution_fabric_controller_test.exs test/xaas_web/controllers/health_controller_test.exs`
   → `Result: 55 passed`

Both targets green. Note: the tasking named the file under `test/xaas_web/controllers/...`;
the real path in this tree is `test/xaas_web/execution_fabric_controller_test.exs` (no
`controllers/` segment) — first run failed with "Paths given to mix test did not match"
and the correct existing path was used throughout.

## Standing

ALIVE for the owned file: the VM-global `INTERNAL_API_TOKEN` delete/restore window is fully
removed from this file (grep-verified: no `delete_env("INTERNAL_API_TOKEN")` remains in
`test/xaas_web/execution_fabric_controller_test.exs`). Other files still deleting the env
(`test/xaas_web/plugs/require_internal_api_token_test.exs`,
`test/xaas_web/ocel_live_server_chain_test.exs`, `test/xaas/chicago/negative_courts/chicago_authority_courts_test.exs`,
`test/xaas/operations/gymact_surface_test.exs`) are OUTSIDE this lane's ownership and remain
the residual leak sources for future lanes.

## Generated vs handwritten

100% handwritten diff (single test rewrite, ~35 lines); no generator owns test trees.

## Falsifiers (how to refute this receipt)

- `grep -n 'delete_env("INTERNAL_API_TOKEN")' test/xaas_web/execution_fabric_controller_test.exs` → must return nothing.
- Either verification command above returning non-green refutes ALIVE.

## W314 audit closure (2026-10-06)

Per-file verdict on `System.delete_env("INTERNAL_API_TOKEN")` residual (4 files):

- `test/xaas_web/plugs/require_internal_api_token_test.exs` — SAFE-serialized.
  Uses `XaasWeb.ConnCase` without `async: true` (defaults async: false);
  `without_env_token/1` restores the prior value in `after` per call.
- `test/xaas_web/ocel_live_server_chain_test.exs` — SAFE-serialized.
  `use ExUnit.Case, async: false`; delete/restore window inside `on_exit`-closed lifecycle.
- `test/xaas/chicago/negative_courts/chicago_authority_courts_test.exs` — SAFE-serialized.
  `async: false` already carries the W280/W158 rationale comment at lines 21-24.
- `test/xaas/operations/gymact_surface_test.exs` — SAFE-serialized.
  `use ExUnit.Case, async: false` with W280/W158 rationale comment already in place.

Zero POISONERs; no code edits required.

Verification (real run, pinned asdf toolchain, INTERNAL_API_TOKEN=dev-e2e-token):
`MIX_ENV=test mix test <the 4 files>` → `22 passed`, 0 failures.
