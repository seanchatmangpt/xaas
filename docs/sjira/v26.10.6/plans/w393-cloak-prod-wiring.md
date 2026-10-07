# W393 — Cloak prod wiring trace (OS-17 evidence completion)

Repo: /Users/sac/xaas @ feat/playwright-surface. Read-only lane; no lib/config edits.

## 1. Config layers

- `config/config.exs`, `config/prod.exs`, `config/runtime.exs`: zero matches for
  `cloak`/`vault`/`CLOAK_KEY` (grep across `config/*.exs` returned nothing).
  No config layer reads env `CLOAK_KEY` and no prod-only validation exists
  (no `Runtime.valid?`, no exit-on-missing, nothing in `runtime.exs`).
- The only place `CLOAK_KEY` is read in lib/ is the vault itself.

## 2. Vault init/start path

- `lib/xaas/vault.ex:18` — `use Cloak.Vault, otp_app: :xaas`.
- `lib/xaas/vault.ex:23` — fallback bytes are a **committed literal**:
  `System.get_env("CLOAK_KEY", "4T4/f5PYK0d489Do8sNU8VNJHKD/1XVOLXyzHUlIkQY=")`
  base64-decoded inline. Not config-driven; the placeholder is public in the repo.
- `lib/xaas/application.ex:112` — `Xaas.Vault` is a real supervised child with
  **no `config_env()` gating** (only other `prod`/`config_env` mention is an
  unrelated comment at line 125). Boots in every environment including prod.

## 3. Prod-path usage

- `lib/xaas/accounts/token.ex:17-18` — `cloak do vault(Xaas.Vault) end` on
  `Xaas.Accounts.Token` (`encrypted_extra_data`).
- `lib/at/xaas/platform/webhook.ex` correction: actually
  `lib/xaas/platform/webhook.ex:48-49` — same cloak block on
  `Xaas.Platform.Webhook` (`secret` at rest).
- Both are runtime resources reachable via the running app, so the vault is
  exercised in prod surfaces: token creation and webhook-secret writes go
  through the fallback key whenever `CLOAK_KEY` is unset.

## 4. Verdict: (b) — nothing guards; fail-open fully reachable in prod (HIGH)

W349's finding stands. Config alone protects nothing: no config layer
references the key, the vault child is unconditional, and the fallback is a
committed literal. W349's own Chicago-style test
(`test/xaas/vault_env_guard_test.exs`) explicitly pins "No runtime prod guard
exists" as the current contract.

### Minimal patch sketch (3 lines in `init/1`, vault.ex:21-32)

```elixir
def init(config) do
  key =
    if Application.get_env(:xaas, :env) == :prod and is_nil(System.get_env("CLOAK_KEY")) do
      raise "CLOAK_KEY must be set in prod"   # or {:stop, :cloak_key_missing}
    else
      System.get_env("CLOAK_KEY", "4T4/...") |> Base.decode64!()
    end
  ...
end
```

Supervisor semantics: prefer `{:stop, :cloak_key_missing}` from `init/1` so the
failure is typed; with `:permanent` restart it will crash-loop the node
(fail-closed), which is the intended posture.
