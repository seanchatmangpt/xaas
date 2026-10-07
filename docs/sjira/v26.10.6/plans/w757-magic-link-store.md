# W757 — magic-link sign-in `AshOnetime.Error :store_invariant` (receipt)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` HEAD `a0723bf6` (working tree drifted mid-lane — another session's stash pop briefly conflicted mix.exs at 03:39, resolved by them; no W757 file changes other than this receipt).
- **Lane scope**: diagnose W727's BLOCKED magic-link sign-in failure. Test-only lane: no lib/config/test changes.

## Verdict

**Classification (b) — lib/db-side schema-drift defect (typed finding for the coordinator, no lane fix).**
Not a test-env config defect: `config/test.exs` is correct. Not an ordering/environment issue:
the failure is deterministic on every first `RevokeNonce` admission in every env whose database
has not had ash_onetime's 1.1 logical-partition upgrade migration applied.

## Root-cause chain (fully traced, repro at HEAD)

1. `sign_in_with_magic_link` (Xaas.Accounts.User) → `AshAuthentication.Strategy.MagicLink.SignInChange`
   `before_action` → `revoke_single_use_token/4` (sign_in_change.ex:81) →
   `AshAuthentication.TokenResource.revoke/3` → **Xaas.Accounts.Token `:revoke_token`**
   (`deps/ash_authentication/lib/ash_authentication/strategies/magic_link/sign_in_change.ex:37,65,90`).
   Magic-link sign-in spends its own token via the very `:revoke_token` action W727 already knew was BLOCKED —
   the two disclosed failures (magic-link sign-in and `:revoke_token`) are **one defect, not two**.
2. `:revoke_token` → `Xaas.Accounts.Token.EnforceSingleRevoke` → `RevokeNonce.claim`
   (ash_onetime `one_time_nonce`, window max_age 300s) → `AshOnetime.Store.claim/2` (Postgres store).
3. Store INSERT: `INSERT INTO ash_onetime_nonce_claims (id, logical_partition, operation_hash, scope_hash, key_hash, issued_at, expires_at, verifier_id, admitted_at, retain_until, inserted_at) ...`
   — ash_onetime **1.2.3** (mix.lock) inserts/queries a **`logical_partition`** column.
4. The test DB's `ash_onetime_nonce_claims` has **10 columns, `logical_partition` NOT among them**
   (queried information_schema, 2026-10-07). xaas's only ash_onetime migration is the 1.0 install
   (`priv/repo/migrations/20260820213658_install_ash_onetime.exs`, whose `create_claim_partitions/1`
   is a no-op because `hash_partitions` was not set — legal: claim parents may be unpartitioned).
   ash_onetime's 1.1 logical-partition upgrade migration was **never generated/applied**
   (`mix ash_onetime.gen.logical_partitions`; required per
   `deps/ash_onetime/documentation/operations.md`: "Existing 1.0 installations must add the
   logical-partition key before using").
5. Postgres `42703` (undefined column) inside the store's claim transaction → rolled back →
   `%Store.Result{status: :failure, reason: :store_invariant, transaction: :rolled_back}` →
   `AshOnetime.Error` `:store_invariant` / "authoritative admission store failed" → sign-in errors.

Vendor's own doctor confirms on the live test DB:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW757 \
  mix ash_onetime.doctor --repo Xaas.Repo --live
# exit 1
# [FAIL] logical_partition column present on all three authority tables (found on: [])
# [OK]   ash_onetime_response_payloads table present
# [OK]   ash_onetime_response_payloads_default partition present
# [OK]   cleanup/reap functions present with exact arities
# [OK]   delete-guard triggers present
# ** (Mix) ash_onetime doctor: 1 check(s) failed
```

## Repro (minimal, exit-path observed at HEAD)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW757 mix run -e '
Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
email = "w757-#{System.unique_integer([:positive])}@example.com"
ctx = [context: %{private: %{ash_authentication?: true}}]
strategy = AshAuthentication.Info.strategy!(Xaas.Accounts.User, :magic_link)
{:ok, token} = AshAuthentication.Strategy.MagicLink.request_token_for_identity(strategy, email)
result = Xaas.Accounts.User |> Ash.Changeset.for_create(:sign_in_with_magic_link, %{token: token}, ctx) |> Ash.create()
# → {:error, ... "authoritative admission store failed" ... [{AshOnetime.Error, :store_invariant}]}
'
```

`:dbg` witness (same run class): `AshOnetime.Store.claim/2` returns
`%Result{reason: :store_invariant, status: :failure, transaction: :rolled_back, admission_dispatch: :sent}`
during `sign_in_with_magic_link`; the `AshOnetime.Change` involved runs on the
`Xaas.Accounts.Token.RevokeNonce` changeset (User carries no onetime protections — verified
`AshOnetime.Resource.Info.protections(Xaas.Accounts.User) == []`).

## Prescribed fix (coordinator, out of lane scope)

1. Generate + run the 1.1 logical-partition upgrade migration in dev AND test:
   `mix ash_onetime.gen.logical_partitions --repo Xaas.Repo`, then `mix ecto.migrate` per env.
   Re-run `mix ash_onetime.doctor --repo Xaas.Repo --live` until "all checks passed".
   One fix repairs BOTH disclosed failures (magic-link sign-in and direct `:revoke_token`).
2. Secondary (advisory, same upgrade debt): add the ash_onetime maintenance queues to Oban
   (`:ash_onetime_cleanup`, `:ash_onetime_reap`, `:ash_onetime_partitions`) — none are in
   `config/config.exs` `Oban` `queues`; per `documentation/operations.md:135-137` a missing
   `:ash_onetime_partitions` queue silently stalls forward payload-partition creation
   (payload partitions currently span 2026_08–2027_08, so runway remains, but the stall is real).
3. W727's pinned test and `test/xaas/accounts/token_revocation_test.exs`'s moduledoc BLOCK note
   should be re-landed as real pass assertions after the migration lands.

## Standing

**BLOCKED resolved to typed root cause (ALIVE as diagnosis)** — classification (b), one shared
defect under both disclosed symptoms. No code/config changed in this lane; only this receipt and
`_build-laneW757` (left on disk for the coordinator — lane `rm -rf` was denied by the permission
system; deletion is the coordinator's cleanup step). Dev DB expected to have the same schema
drift (same migration set) — not separately verified; the doctor `--live` command above runs per env.
