# W984cw5 — Accounts burn-down court: `Xaas.Accounts.Token.RevokeVerifier`

Lane: W984cw5, xaas v26.10.6 campaign. Date: 2026-10-07.
Subject: branch `feat/playwright-surface` (working tree, uncommitted lane edits
present — W984cw5 wrote only `test/xaas/accounts/revoke_verifier_depth_test.exs`
plus this receipt; no commit per lane contract).

## Census (W984cj map method re-run, accounts scope)

`lib/xaas/accounts/` = 13 modules, 1,339 lines:

| Module | Lines | Direct-test coverage at census |
|---|---|---|
| user.ex (Xaas.Accounts.User) | 347 | sensitive-probe-only (lane contract exclusion) |
| org.ex | 250 | COVERED (`org_test.exs`) |
| token.ex | 146 | sensitive-probe-only (`token_revocation_test.exs` indirect) |
| org_membership.ex | 134 | COVERED (`org_membership_test.exs`, destroy-depth) |
| checks/actor_belongs_to_org.ex | 95 | COVERED (named in 3 test files) |
| validations/org_suspended_requires_suspension_reason.ex | 83 | COVERED (`org_suspension_validation_depth_test.exs` — W984bw) |
| checks/actor_org_self_filter.ex | 74 | COVERED (named in 3 test files) |
| token/revoke_nonce.ex | 53 | INDIRECT (`token_revocation_test.exs` exercises `:claim` via the real `:revoke_token` path; single-replay refusal courted) |
| token/enforce_single_revoke.ex | 47 | INDIRECT (same path) |
| user/senders/* (3) | 71 | email senders, non-state-bearing, out of lane scope |
| **token/revoke_verifier.ex** | **39** | **UNCOVERED — zero references anywhere in `test/`** |

No invitation/role lifecycle surfaces exist in `lib/xaas/accounts/` — the burn-down
surface is exactly this one module.

## Disposition

`RevokeVerifier` is genuinely non-sensitive and state-bearing in the contract
sense: it is the trusted-key derivation that `ash_onetime`'s one-time-nonce
protection on `Xaas.Accounts.Token`'s `:revoke_token` action is keyed on
(`:crypto.mac(:hmac, :sha256, key, raw_token)`), so a derivation drift breaks or
weakens single-revoke fleet-wide. It touches no resource rows and no User/Token
data — it is a pure function of (configured key, untrusted binary input).

Court: `test/xaas/accounts/revoke_verifier_depth_test.exs` — 5 tests, real
Chicago-style (direct real behaviour implementation, independent `:crypto.mac`
recomputation of the contract; no mocks, no DB needed — `async: true`):

1. Happy path → `{:ok, %AshOnetime.Verified{}}` with pinned
   `verifier_id: "xaas.accounts.token.revoke_verifier/1"`, 32-byte binary key.
2. Key is the exact HMAC-SHA256 of the raw token under the real test-config key
   (`config/test.exs:65`), recomputed independently in the test.
3. Determinism + injectivity: same token → same key; distinct tokens → distinct keys.
4. Guard refusals: `nil`, `42`, `""`, `:atom` → `{:error, :invalid_token}`.
5. Metadata pins: `algorithm() == :hmac_sha256`, `trust_model() == :same_service`,
   `issued_at` freshness bounded by wall clock.

## Verification (real commands, real output)

Run 1 (fresh `_build-laneW984cw5`, pinned asdf toolchain, MIX_ENV=test):

```
Running ExUnit with seed: 528454, max_cases: 32
.....
Finished in 0.1 seconds
Result: 5 passed
[exited with code 0]
```

Run 2 (second `rm -rf _build-laneW984cw5` fresh root, executed after this
receipt was first drafted):

```
.....
Finished in 0.02 seconds
Result: 5 passed
[exited with code 0]
```

## Standing

ALIVE — the census and the court are executed output; the module now has a
direct non-vacuous court (mutations 1–5 each kill a distinct derivation/guard
class: wrong id, unkeyed/wrongly-keyed digest, randomized or colliding key,
dropped guard, metadata drift).

Typed dispositions:
- User/Token resources: sensitive-probe-only per lane contract (established by
  prior lanes W984bw/W984ct2; unchanged).
- No invitation/role surfaces exist: UNSUPPORTED(surface-absent), not forced.
- Accounts domain after this lane: 13 modules, 12 with direct or indirect
  court coverage; the 3 user senders remain non-state-bearing infrastructure.

## Cleanup

`_build-laneW984cw5` left on disk intentionally (used for run 1 + run 2; coordinator
deletes at integration per fanout cleanup law). Estimated ~350M.
