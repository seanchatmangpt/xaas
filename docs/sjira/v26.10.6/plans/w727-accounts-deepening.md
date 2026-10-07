# W727 — Accounts domain deepening (receipt)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf6`, uncommitted lane diff = 1 new file `test/xaas/accounts_deepening_test.exs` (tests only, no routes, no lib changes).
- **Lane scope**: (a) Org create + membership lifecycle, (b) cross-tenant integrity, (c) magic-link invalid-token config pin, (d) User email uniqueness — real Ash actions on the real sandboxed Postgres, Chicago-style, no mocks.
- **Standing**: **ALIVE (partial)** — 15/15 tests pass on the exact subject; one disclosed pre-existing lib-level BLOCK pinned in-test (below).

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW727 \
  mix test test/xaas/accounts_deepening_test.exs
# → exit 0, "Result: 15 passed" (tail: "Result: 15 passed", 3.2s async)
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW727 \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test/xaas/accounts_deepening_test.exs"]))'
# → []
```

Lane build root `_build-laneW727` deleted at integration.

## What the tests assert (all real row state)

- **(a)** Org `:create` persists `name`/`slug`, `:active` default; duplicate `slug` → typed "has already been taken" refusal (`unique_slug`). Membership invite defaults `role: :member`; `:member -> :admin` via real `:update` persists; out-of-constraint role (`:owner`) refused (`InvalidAttribute`, one-of `[member, admin]`); duplicate `(user_id, org_id)` → typed refusal (`unique_user_org`); `:destroy` deletes the row, User/Org survive.
- **(b)** Membership `:user`/`:org` relationships load real referenced rows; membership with nonexistent `org_id` refused (FK integrity); **org deletion is refused: `Org` ships no `:destroy` action** (`Ash.Error.Invalid`, "No primary action of type :destroy") — deletion is the `ApprovalOrgDelete` maker-checker flow. Asserted which: refuses, no cascade path exists at the resource level.
- **(c)** `return_error_on_invalid_magic_link_token? true` pinned (config/config.exs:34) + real AshAuthentication call: garbage token → `{:error, _}`, no silent ok, no phantom row. Plus a real token round trip (see BLOCK below).
- **(d)** Duplicate email via real `:register_with_password` → typed refusal ("has already been taken"), exactly one row survives; case-insensitive collision via `ci_string` + `unique_email` also refuses.

## Typed gaps / falsifiers

- **BLOCKED (pre-existing, lib-level, NOT fixed in this lane)**: `sign_in_with_magic_link` with a real, just-minted magic-link token deterministically fails under `MIX_ENV=test` with `AshOnetime.Error` `:store_invariant` / "authoritative admission store failed" (reproduced 2026-10-07, sandboxed, twice, exact message captured). Same failure class already disclosed in `test/xaas/accounts/token_revocation_test.exs`'s moduledoc (`:revoke_token` path). The test pins this BLOCKED state: real token minted via real `:request_magic_link` ActionInput + real sender output captured via `ExUnit.CaptureIO`; the sign-in is asserted to fail with `AshOnetime.Error code: :store_invariant`. Invalid-token path is unaffected (errors correctly) — the config pin (c) holds.
- Honest test-side corrections made during the run (not lib defects): `register_with_password` requires `password_confirmation`; `request_magic_link` is a generic `:action` (ActionInput, returns `:ok`); `Ash.get` on a destroyed row returns `Ash.Error.Invalid` wrapping `Ash.Error.Query.NotFound`; Token rows expose no `:token` field (jti-only).

## Notes

- `error_with_message?/2` matches `Exception.message/1` text; Ash interpolates vars (`%{atom_list}`) but renders them in `Exception.message/1`, so the real constraint surface (`member, admin`) is pinned.
- No `:eu_ai_act` tag — not tied.
- Mock gate `[]`. No routes touched. Not committed (per lane contract); coordinator owns integration commit.
