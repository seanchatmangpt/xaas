# W183 — Token revocation court + findings (receipt)

*Backfilled by coordinator from lane completion report.* Subject: /Users/sac/xaas @ feat/playwright-surface, 2026-10-06.

## What landed
`test/xaas/accounts/token_revocation_test.exs` — 4 tests, all passing (real Ecto sandbox + real Ash + real AshAuthentication JWTs; accounts dir 23 passed):
1. DSL pinning: `:is_revoked` action exists, `:"revoked?"` gone, `token_revocation_is_revoked_action_name/1` resolves the pinned name.
2. Real consumer wiring: `token_revoked?/3` / `jti_revoked?/3` flip false→true across real `:revoke_jti`; revocation row asserted by jti in the real table.

## Disclosed findings → OS-12
- `:revoke_token` BLOCKED in MIX_ENV=test: EnforceSingleRevoke → RevokeNonce.claim fails first call with AshOnetime `:store_invariant` (deps/ash_onetime/admission.ex) — probed sandboxed + unsandboxed. Lifecycle covered via `:revoke_jti` (same `:is_revoked` check). Needs ash_onetime-owner admission-store decision.
- jti PK collision under `store_all_tokens?(true)` (revocation row reuses token row's jti PK; test clears pre-stored row in-sandbox) — revocation-row identity design question.

Both: convergence-honest disclosures, not DoD failures.
