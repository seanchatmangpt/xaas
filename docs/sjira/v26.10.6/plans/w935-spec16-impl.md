# W935 — SPEC-16 + SPEC-17 Implementation Receipt

Standing: ALIVE (observed execution on this branch's working tree, uncommitted per lane law)
Repo: /Users/sac/xaas, branch `feat/playwright-surface` (no commit; coordinator owns transitions)

## Subject (diff)

- `lib/xaas/governance/audit_export_token.ex` — new `update :use` action
  (accept([]), `require_atomic?(false)`), gated by
  `AuditExportTokenNoActiveFreezeWindow` (W801) + new
  `AuditExportTokenExpiredTokenRefused` (SPEC-17) +
  `AuditExportTokenNotAlreadyUsed`; stamps `used_at`, `increment(:use_count, amount: 1)`;
  new `used_at` (nullable, non-writable) + `use_count` (default 0, non-writable)
  attributes; `bypass action(:use)` policy (org-match, same idiom as :issue/:revoke);
  `patch(:use)` json_api route.
- `lib/xaas/governance/validations/audit_export_token_not_already_used.ex` — new.
- `lib/xaas/governance/validations/audit_export_token_expired_token_refused.ex` — new.
- `priv/repo/migrations/20261007220000_add_used_at_and_use_count_to_audit_export_tokens.exs` — new.
- `test/xaas/governance/export_token_deepening_test.exs` — the two W765 disclosed-gap
  tests in section (b) flipped to closed-gap courts; 6 new courts added (21 total).

## SPEC-17 disposition

Implemented in-lane (stayed small): `AuditExportTokenExpiredTokenRefused` on the `:use`
path, typed `Ash.Error.Invalid` field `:expires_at`, message "token is expired". No
resume key needed; SPEC-17 is closed by this diff, not merely unblocked.

## Verification (real commands, real output)

- `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW935 mix test test/xaas/governance/export_token_deepening_test.exs`
  → `Result: 21 passed` ×2 (both runs on final source, after the increment-form repair).
- Mutation kills witnessed:
  - remove `AuditExportTokenExpiredTokenRefused` validate line → `20/21 passed`
    (SPEC-17 court fails: expired token consumed instead of refused).
  - remove `AuditExportTokenNotAlreadyUsed` validate line → `20/21 passed`
    (SPEC-16 second-use court fails: counter advances past 1).
  - Both lines restored; final post-restore run `21 passed`.
- Migration applied by the `test` alias (`ecto.migrate --quiet`); the
  used_at/use_count courts read real columns in sandboxed Postgres.

## Mid-lane repair (coordinator escalation)

Original `change(increment(:use_count, 1))` (positional amount) crashed
`Keyword.put_new` at module-compile and blocked tree-wide test compile (W902/W945/W946).
Vendored Ash (`deps/ash/lib/ash/resource/change/builtins.ex:122`) signature is
`increment(attribute, opts \\ [])` — keyword opts. Landed
`increment(:use_count, amount: 1)`; tree compile now clean (only pre-existing
dataset_admission.ex @doc warning remains — pre-existing, not this lane's).

## Falsifier status

- Closed: W765 GAP-B (no consume surface) and GAP-C (reuse-after-expiry unrefused).
- Mutation rationale is inline at each new court in the test file.

## Not done (typed, disclosed)

- No commit (lane law: coordinator owns transitions).
- `mix xaas.verify_and_commit` full gate not run (lane scope is the deepening file;
  full-suite gate is W946's).
- `_build-laneW935` left in place for coordinator cleanup (rm denied in this session's
  permission set); per dispatch it may be left for the coordinator when deletion fails.
