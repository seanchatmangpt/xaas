# W765 — AuditExportToken + FreezeWindow deepening (receipt)

- **Lane**: W765, v26.10.6 campaign, /Users/sac/xaas @ a0723bf6 (feat/playwright-surface)
- **Files written**: `test/xaas/governance/export_token_deepening_test.exs` (new, 11 tests) + this receipt. Nothing else touched; nothing committed.
- **Command**: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW765 mix test test/xaas/governance/export_token_deepening_test.exs`
- **Real output (tail)**:

```
Running ExUnit with seed: 900610, max_cases: 32
...........
Finished in 1.2 seconds (1.2s async, 0.00s sync)
Result: 11 passed
[exited with code 0]
```

- **Standing**: ALIVE — 11/11 real Ash-action tests against sandboxed Postgres, exit 0.
- **Cleanup**: `_build-laneW765` deleted after the run.

## What the tests pin (real semantics per the code)

1. **Mint**: `:issue` (accepts only `org_id`/`created_by`) mints `aet_live_` raw token; persisted `token_hash` is exactly sha256(raw), 64 hex chars; `token_prefix` = first 12 chars of raw; `scope` = "audit:read"; raw returned exactly once via changeset context.
2. **TTL semantics (real, disclosed)**: `expires_at` is NOT in `:issue`'s accept list — every minted token is non-expiring unless force-set. The `active?` calculation (`is_nil(revoked_at) and (is_nil(expires_at) or expires_at > now())`) correctly computes false for expired, true for future-dated.
3. **Reuse-after-use: honest typed gap (W715 pattern)** — no `:use`/`:consume`/`:verify` action exists; token state unchanged after hash-derivation "use"; single-use not enforced.
4. **Reuse-after-expiry: honest typed gap** — no action refuses an expired use; only `active?` flips; expiry is non-destructive (revoked_at stays nil, hash persists). Action surface is exactly `[:issue, :read, :revoke]`.
5. **Already-revoked guard** (`AuditExportTokenNotAlreadyRevoked`, cited by ApprovalNotAlreadyApproved court idiom): revoke → `revoked_at` set, `active?` false, hash persists; second revoke refuses with typed `Ash.Error.Invalid` field `:revoked_at`, message "token is already revoked", and leaves the persisted `revoked_at` unchanged.
6. **Determinism**: two mints same org never collide on hash/prefix/raw; derivation is deterministic — sha256(raw) reproduces the stored hash exactly.
7. **FreezeWindow — what an active freeze actually blocks**: a window is inert by itself (no in-process consumer gates on `starts_at`/`ends_at` — disclosed gap; "active freeze blocks deploys" is not implemented in-process). The only enforcement point is `ApprovalFreezeOverrideFreezeWindowExists`: existence + same-org + `allow_emergency_override` must be true. Tests pin: `ends_at > starts_at` typed refusal (equal and inverted both refused, no row persisted); emergency-eligible window accepts an override; `allow_emergency_override: false` refuses; foreign-org window refuses (cross-org integrity).

## Typed gaps disclosed (real-read of the code, asserted in tests)

- GAP-A: no mint-time TTL input — `expires_at` not accepted by `:issue`.
- GAP-B: no single-use / use-tracking enforcement (`:use` absent).
- GAP-C: no action refuses reuse-after-expiry (calculation-only).
- GAP-D: no runtime consumer gates any action on an active freeze window; the window acts only through the override gate.

## Falsifier status

All asserted semantics passed on the exact subject (11/11, exit 0); no vacuous assertions (the ones written mid-draft were removed before the run).
