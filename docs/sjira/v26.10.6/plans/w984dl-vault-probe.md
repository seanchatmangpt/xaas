# W984dl — Vault-family coverage burn-down (G1 Core Security & Vault)

Lane: W984dl, xaas v26.10.6, branch `feat/playwright-surface`.
Scope discipline: wrote only tests + this receipt; no commit (per lane
contract).

## Census (CamelCase-aware map)

`lib/xaas/vault*` = exactly **one module**: `Xaas.Vault`
(`lib/xaas/vault.ex`, 42 lines) — a `Cloak.Vault` used by `AshCloak` for
`Xaas.Accounts.Token` and `Xaas.Platform.Webhook`. No `lib/xaas/vault/`
directory exists; no other `Xaas.Vault*` modules exist.

Prior coverage: `test/xaas/vault_env_guard_test.exs` (W349, 4 tests) —
env-override round trip, placeholder-fallback key equivalence, disclosure
pin (stale-moduledoc note vs. the OS-17 guard now present in source; the
tests themselves still pass and their assertions remain true under
`MIX_ENV=test`), OS-17 source pin. Honest status: family was PARTIALLY
covered, refusal-half uncovered.

## Court

New file: `test/xaas/vault/vault_depth_court_test.exs` — 5-test depth
court, all through real public APIs (`Vault.encrypt/decrypt`,
independent `Cloak.Ciphers.AES.GCM` calls, real `CLOAK_KEY` env
manipulation, real child restart via the owning supervisor). No mocks;
key material used is only a fresh random per-compile key and the already
committed placeholder from `lib/xaas/vault.ex` — nothing new.

1. **Sealed-storage round trip** (short/empty/64 KiB plaintexts) under a
   fresh `CLOAK_KEY` — kills a default-cipher-key-ignores-env mutant.
2. **Tamper refusal** — every single-bit mutation of the GCM-protected
   payload refuses (`:error` / `{:ok, :error}`, Cloak's typed refusal
   shapes); pins that the leading format-version byte is OUTSIDE GCM
   authentication (flipping it still decrypts — documented tolerance, not
   a bug; kills a silent-authentication-change mutant).
3. **Wrong-key refusal** — foreign-key ciphertext never yields foreign
   plaintext through `Vault.decrypt/1`; symmetric independent-cipher
   check that our blob won't open under the foreign key. Kills a
   cross-environment key-replay mutant.
4. **Malformed `CLOAK_KEY`** — non-base64 key material refuses startup
   (start failure, no live process). Kills a swallow-and-fallback init
   mutant.
5. **Conditional fail-closed guard** — with no `CLOAK_KEY`, the vault
   boots under test env and data is keyed by the committed placeholder
   (kills a guard-removes-condition mutant that would break the dev/test
   fallback).

## Verification (real run, fresh lane build root)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dl \
  mix test test/xaas/vault/vault_depth_court_test.exs \
           test/xaas/vault_env_guard_test.exs
=> Result: 9 passed (0 failures, 0 skipped of mine)
```

Build root `_build-laneW984dl` left on disk (rm denied by permission
system; per lane contract, coordinator deletes it).

## Standing

- Court: **ALIVE** — 5/5 executed and passing on the exact subject
  (working tree of `feat/playwright-surface` at census time).
- Family coverage disposition: prior tests COVERED key-selection
  contracts; this court closes the refusal-half. Vault family now
  covered for key handling, round trips, tamper, wrong-key, malformed
  key, and the conditional prod guard pin. **PARTIAL_ALIVE → ALIVE for
  the G1 vault family**, modulo coordinator commit.

## Findings of note

- Cloak 1.1.4 blob layout `<<version, tag_len, tag, iv, ct>>`: the
  version byte is unauthenticated (single-bit flip still decrypts).
  This is a Cloak library design fact, pinned as documented behavior;
  no fix in scope for this lane.
- Cloak refusal vocabulary is `:error` / `{:ok, :error}` (GCM maps auth
  failure to `{:ok, :error}`) — future vault tests should assert on
  these shapes, not `{:error, _}` only.

## Falsifiers

- Court fails if any tampered payload byte decrypts to plaintext.
- Court fails if foreign-key ciphertext yields foreign plaintext.
- Court fails if the vault boots on malformed key material.
- Court fails if removing the `Mix.env() == :prod` condition (breaking
  the dev/test placeholder fallback) or removing the OS-17 `{:stop,...}`
  clause changes test-env boot behavior.
