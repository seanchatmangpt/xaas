# W349 — CLOAK_KEY env-override guard test (closure row 5)

- Repo: /Users/sac/xaas @ feat/playwright-surface (lane W349, P1-4 test-only boundary)
- Subject: `lib/xaas/vault.ex` (committed CLOAK_KEY placeholder)
- Test file: `test/xaas/vault_env_guard_test.exs`

## Contract pinned

1. `CLOAK_KEY` set → real value used as default cipher key: real
   encrypt/decrypt round-trip through a live `Xaas.Vault` GenServer, and the
   ciphertext differs from the same plaintext under the committed placeholder
   key (independent real AES.GCM.V1 cipher, no mocks).
2. `CLOAK_KEY` unset → committed placeholder
   (`4T4/f5PYK0d489Do8sNU8VNJHKD/1XVOLXyzHUlIkQY=`) is the fallback key
   (ciphertext equality with an independent encryption under the placeholder).
3. Prod guard: `vault.ex` documents "must NOT be used in production" in its
   moduledoc but `init/1` enforces NOTHING — an unset `CLOAK_KEY` in prod
   boots the vault silently on the publicly-committed placeholder. Typed
   disclosure: **no runtime prod guard exists**; per P1-4 (tests only) this
   lane pins current behavior and does not add lib code. Row 5 stays
   PARTIALLY OPEN: guard test exists; prod guard is a decision.

## Mechanics

- async: false; env mutated via `System.put_env/delete_env`, restored in
  `on_exit`.
- The app-booted vault is terminated via its owning supervisor
  (proc_lib ancestor), restarted under ExUnit's test supervisor with the
  desired env, and restored in `on_exit` — so the test does not fight the
  application supervisor's auto-restart.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW349 \
  mix test test/xaas/vault_env_guard_test.exs
```
