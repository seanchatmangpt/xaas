# W726 — Witness identity-constraint typed refusal fix

- **Subject**: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6`
- **Standing**: ALIVE — fix observed on the exact subject (real Postgres
  `xaas_test`, real Ash creates); mutation falsifier executed for real
  (revert → 4 courts fail with `class: :unknown`; restore → green).
- **Date**: 2026-10-07
- **Task origin**: W698 receipt, finding 1 (typed-refusal degradation).

## Root cause

Migration `20261005000000` created the witness identity indexes with
Ecto's column-derived names:

- `witness_certified_receipts_subject_payload_hash_hex_index`
- `witness_verification_keys_kid_index`

Ash derives the expected constraint name from the resource identity name:
`..._unique_subject_payload_index` / `..._unique_kid_index`. On duplicate
create, AshPostgres did not recognize the constraint, so the refusal
surfaced as `Ash.Error.Unknown` wrapping the raw `Ecto.ConstraintError`.

## Fix (minimal: DB-side only, no resource/policy edits)

New migration `priv/repo/migrations/20261007000000_rename_witness_identity_indexes.exs`:
guarded `ALTER INDEX ... RENAME` for both indexes (DO $$ … $$ blocks; no-op
when the target name already exists). `down` renames back. No policy,
action, or identity change; deny-by-default policies untouched.

## Regression courts (test/xaas/witness/witness_surface_deepening_test.exs, extend-only)

1. "ingest refuses a second row..." — upgraded: now asserts the typed
   `%Ash.Error.Changes.InvalidAttribute{field: :subject, message: "has
   already been taken"}` inside `%Ash.Error.Invalid{}` (error shape
   verified by a real probe: `err.class == :invalid`).
2. **NEW** "(w726) a direct duplicate ingest surfaces a typed Invalid,
   not Ash.Error.Unknown" — both the positive match and an explicit
   `refute match?({:error, %Ash.Error.Unknown{}} ...)` on the exact same
   duplicate create.
3. **NEW** "(w726) a direct duplicate kid registration surfaces a typed
   Invalid" — VerificationKey duplicate `kid` create asserts
   `%Ash.Error.Invalid{}`; original row preserved.
4. **NEW** "(w726) Catalog.ingest/1 of the same signing surface twice is
   idempotent" — same surface ingested twice: identical receipt ids, no
   new rows; Catalog's existing-receipt fallback behavior unchanged by
   the rename (it matches on any `{:error, _}`).

## Mutation rationale (executed)

Reverting the rename (real `ALTER INDEX ... RENAME` back to the old
column-derived names on `xaas_test`) and rerunning the deepening file:
**7/11 passed, 4 failed** — all failures show `class: :unknown` (the
`%Ash.Error.Invalid{}` asserts on the duplicate creates fail). So the
courts bind to the fix, not to refusal-presence. Restored the indexes;
rerun: 46 passed.

## Commands / exits

```
# fresh lane build root compiled from scratch (~12 min)
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW726 \
  mix ecto.migrate                 → exit 0; migration 20261007000000 up
psql xaas_test (index names)      → both Ash-derived names present

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW726 \
  mix test test/xaas/witness/ --include eu_ai_act
  → Result: 46 passed, 9 excluded   (43 pre-existing witness tests + 3 new)

# mutation run
ALTER INDEX ... (rename back)      → deepening file: 7/11 passed, 4 failed, class :unknown
ALTER INDEX ... (restore)          → Result: 46 passed, 9 excluded
```

ML-DSA `provider signature failure` stderr lines are the expected
tampered-message negative controls, not failures.

## Environment / replay

- elixir 1.20.2-otp-28 / erlang 28.5.0.2 via asdf; `MIX_ENV=test`.
- `_build-laneW726` (~437 MB) left in place per lane contract for the
  coordinator to delete at integration.
- No commits made; working tree carries the migration, the extended test
  file, and this receipt.
