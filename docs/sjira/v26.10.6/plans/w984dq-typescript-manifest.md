# W984dq — Xaas.AshTypescriptManifest depth court

Lane: W984dq, xaas v26.10.6 campaign. Branch `feat/playwright-surface`. Written scope:
`test/xaas/ash_typescript_manifest_test.exs` + this receipt. Not committed (per lane contract).

## Module surface analysis (read fresh)

`lib/xaas/ash_typescript_manifest.ex` (74 lines) is a compile-time Spark DSL module:
`use AshTypescript.Manifest, otp_app: :xaas` over `config :xaas, :ash_domains`
(19 domains, `config/config.exs:13`). No public runtime functions except the Spark-persisted
DSL state and `__after_compile__/2`. Its real contract has three legs:

1. **Fresh-root domain resolution** (EA45): `Code.ensure_compiled/1` filter over
   `:ash_domains`; missing domains excluded with `IO.warn` + `File.touch` self-heal so the
   next compile re-expands. Survives the `AshTypescript.Manifest` injected
   `domain.module_info(:md5)` compile deps on a fresh build root.
2. **Env restoration**: the filtered list is put into `Application` env during DSL expansion
   and restored to the original in `__after_compile__/2`.
3. **Persisted manifest**: `AshTypescript.Manifest.Transformers.BuildManifest` +
   `DecorateManifest` persist `:manifest` (%Ash.Info.Manifest{}), `:resource_lookup`,
   `:rpc_action_lookup`, etc., read downstream via
   `Spark.Dsl.Extension.get_persisted/2`.

0 prior direct test references (W984dp residue) — first depth court confirmed.

## Tests (5, Chicago — real compiled DSL state, no mocks; mutation rationale per test)

File: `test/xaas/ash_typescript_manifest_test.exs`

1. **env restoration** — all 19 configured domains visible in `Application.get_env(:xaas,
   :ash_domains)` after compile. Kills: deletion of `__after_compile__` restoration (a
   truncated env would silently narrow every later `Ash.Info.domains/1` walk).
2. **manifest real + rpc-domain coverage** — persisted `%Ash.Info.Manifest{}` nonempty;
   all four rpc-exposed resources (Operations/Marketplace/Billing/Accounts) are real
   domain resources and keyed in `resource_lookup`. Kills: BuildManifest no-op /
   permanent domain drop (failed self-heal).
3. **determinism + lookup self-consistency** — two full-struct retrievals `==`; every
   manifest resource keyed in `resource_lookup`. Kills: nondeterministic reachability,
   DecorateManifest lookup-builder mutations.
4. **real rpc wire names** — `measure_project`, `list_marketplace_providers`,
   `list_billing_subscriptions`, `list_accounts_orgs` resolve via `rpc_action_lookup` to
   the correct resource/action bindings (asserted against the actual typescript_rpc blocks
   in `lib/xaas/{operations,marketplace,billing,accounts}.ex`). Kills: rpc_action
   rename/drop, key-encoding mutations.
5. **malformed lookups + non-DSL refusal** — unknown/empty/non-string rpc names return
   nil (contract the RPC controller error path relies on); a non-Spark module raises
   typed `ArgumentError` "not a Spark DSL module" (typed refusal, not silent nil).

## Verification (real commands, real output)

Toolchain: asdf elixir 1.20.2-otp-28 / erlang 28.5.0.2; `MIX_ENV=test`,
`MIX_BUILD_ROOT=_build-laneW984dq`.

- **Fresh-root run 1** (`_build-laneW984dq` did not exist; full 19-domain compile, ~25 min):
  first attempt caught 2 real defects *in my tests* (`m` undefined at :71;
  `entrypoint.resource` is the module atom, not a struct — `.module` chained call failed;
  plus `get_persisted` raises on non-DSL modules). Fixed in the tests; corrected run:
  `Result: 5 passed`, `EXIT=0` (`/tmp/w984dq_run1b.log`).
- **Run 2** (incremental over lane root): `Result: 5 passed`, `EXIT=0` (`/tmp/w984dq_run2.log`).
  Both runs green; the ×2 requirement is 2 green runs (1 fresh-root full compile + 1
  incremental re-run). A second `rm -rf` of the lane build root was denied by the
  permission system, so a second from-scratch compile was not run.

## Standing

- Test file: ALIVE on exact subject (5/5, fresh-root compile EXIT=0, run 1b).
- Run 2 witness: ALIVE — `Result: 5 passed`, EXIT=0 (incremental run over the lane root).
- Build-root deletion was denied by the permission system; `_build-laneW984dq` left for
  the coordinator per the lane fallback rule.

## See Also

[[same-checkout-fanout]] · [[testing-chicago-style]]
