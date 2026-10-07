# W701 — ash_a2a→xaas legacy_compat config gaps (cross-project gap wave)

Lane W701 · Repo /Users/sac/xaas @ feat/playwright-surface · Build root `_build-laneW701` · Toolchain asdf elixir 1.20.2-otp-28 / erlang 28.5.0.2 (dev); compile/tests ran under asdf shims with `MIX_BUILD_ROOT=_build-laneW701 MIX_ENV=test`.

## Task

Fill xaas's `:ash_a2a` config gaps behind W605's AIRo mapping of the seven
`AshA2A.SecurityProfile.Boot` legacy_compat warning classes so the xaas
runtime stops booting degraded/legacy.

## Diff (4 files, +1 receipt)

- `config/dev.exs` — full strict-fill config block (replaces the bare
  `security_profile: :legacy_compat`): durable `ReceiptStore.Ekv` +
  persistent `data_dir`, persistent outbox dir + HMAC keys (dev literal
  defaults, env-overridable), durable-file claim store + dir + key, EKV
  authority broker `{AshA2A.Authority.Broker.Ekv, data_dir: …}`,
  `kill_switch_class: :xaas_a2a` + durable `:kill_switch_path`,
  `security_profile: :strict`.
- `config/runtime.exs` — two additions:
  - prod: env-sourced, fail-closed strict block (raises without
    `XAAS_A2A_DATA_DIR` / base64 `XAAS_A2A_OUTBOX_KEY` /
    `XAAS_A2A_BINDING_KEY` / `XAAS_A2A_CLAIM_STORE_KEY`; same durable
    shape as dev) — mirrors the ash_a2a production checklist.
  - dev: `capability_release_mode: :strict` set at RUNTIME only.
- `config/test.exs` — authority half filled (real `Broker.InMemory`,
  `kill_switch_class: :xaas_a2a_test`); profile stays `:legacy_compat` by
  design (memory receipt store + tmp outbox are correct for the test court;
  documented inline).
- `test/xaas/ash_a2a_config_court_test.exs` — NEW court (6 tests, Chicago:
  real `AshA2A.SecurityProfile.Boot` / `AshA2A.Authority.SecurityPreflight` /
  `AshA2A.ReceiptStore.durable_path?/1`, no mocks): asserts test-env config
  resolves, that the exact dev env map yields `Boot.violations(:strict, …)
  == []` and `SecurityPreflight.check/0 == :ok`, durable-path checks, and
  the W605 AIRo `ash_a2a_airo.ttl` RiskSource individuals for the seven
  targeted classes are present and controlled by the supplied config keys.

## Per-class table (the 7 KNOWN gap classes)

| class | before | after |
|---|---|---|
| authority_broker_missing | missing everywhere | dev: EKV broker + persistent dir; test: real Broker.InMemory; prod: EKV broker (runtime, fail-closed) |
| kill_switch_class_missing | missing everywhere | dev `:xaas_a2a` + durable dets path; test `:xaas_a2a_test`; prod `:xaas_a2a` + dets (runtime) |
| claim_store_missing (+ dir/key) | missing everywhere | dev/prod: DurableFile + persistent dir + HMAC key; test: legacy by design |
| receipt_store_in_memory | missing everywhere | dev/prod: `ReceiptStore.Ekv` + persistent `data_dir`; test: memory by design |
| outbox_dir_not_durable | missing everywhere | dev/prod: persistent outbox dir; test: legacy by design |
| outbox_key_missing | missing everywhere | dev: 32+ byte literal keys (env-overridable); prod: base64 env keys, fail-closed; test: legacy by design |
| capability_release_mode_legacy | missing everywhere | dev: `:strict` via runtime.exs; prod: `:strict` via runtime.exs; test: legacy by design |

## Measured refusal (real finding)

`capability_release_mode: :strict` in COMPILE-TIME config fails the ash_a2a
dep's own compile: `lib/ash_a2a/chicago/bench/b11_wire.ex` refuses
`:capability_release_closure_missing` while expanding agent cards at compile
time (`cannot build released AgentCard: :capability_release_closure_missing`,
observed in the W701 lane build). The strict release gate requires the frozen
`capability_release_closure` as a boot prerequisite; the closure is a
per-deployment frozen skill set (AshA2A moving it to runtime.exs avoids the
same refusal in ash_a2a's own prod). Hence `:strict` release mode is set in
runtime.exs (dev + prod), never in compile-time config. Test env stays
`:legacy` release mode by design.

## Verification (actual output)

    $ PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW701 MIX_ENV=test mix compile
    Generated xaas app                       (exit 0)

    $ … mix test test/xaas/ash_a2a_config_court_test.exs
    Result: 6 passed

    $ … mix test test/xaas_web/a2a test/xaas/sa2a
    Result: 126 passed, 18 skipped, 1 excluded

At test boot the legacy_compat warnings now enumerate only the deliberately
legacy classes (outbox/claim/receipt-store/capability-release), and
`authority_broker_missing` / `kill_switch_class_missing` no longer fire —
observed in the test run tail. An intermediate failure (restore leaking
`put_env(k, nil)` shadowing library defaults) was fixed at the artifact with
`delete_env` for unset keys, not by loosening assertions. The
`ash_a2a_airo.ttl` is read from the canonical ash_a2a checkout (W605's TTL is
uncommitted; the dep build-dir priv copy only carries committed files).

## Standing / residuals

- Dev `:strict` profile boot itself is UNWITNESSED (dev compile is barred on
  this host — live phx server; the falsifier is the next dev
  `mix phx.server` restart, which the court predicts boots warning-free).
- Test env keeps 4 deliberately-legacy classes (memory store, tmp outbox,
  unkeyed outbox, legacy release mode) — documented in test.exs, correct for
  the test court.
- Strict capability release needs a frozen `:capability_release_closure`
  before it has effect at dispatch; that closure is a per-deployment work
  order, not config.
