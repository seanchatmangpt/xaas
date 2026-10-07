# W971b — Migration Replay Safety (epoch dedup migrations idempotent)

Lane: W971b · Campaign: xaas v26.10.6 · Date: 2026-10-07
Branch: `feat/playwright-surface` (uncommitted, lane-owned files only)

## Subject

Four migrations replay-guarded so a DB holding their objects (created by
direct DDL) but missing their `schema_migrations` rows migrates cleanly:

- `priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs`
- `priv/repo/migrations/20261007120000_dedup_orgless_epochs_then_unique_index.exs` (already guarded — `create_if_not_exists`, idempotent DELETE; unchanged)
- `priv/repo/migrations/20261007210000...` and `20261007220000...` — guarded via private `column_exists?/2` helper (Ecto.Migration ships no such helper; first attempt using `column_exists?`/`add_if_not_exists`/`remove_if_exists` was compile- or reverse-error at first rollback: `cannot reverse migration command: alter table audit_export_tokens` and `undefined function column_exists?/2`)
- 111457: `add_partition_column` guarded by `column_exists?`; `replace_collision_constraint` short-circuits when the logical constraint already exists (on replay the legacy constraint is already dropped, so the unguarded path raised `legacy ash_onetime collision constraint is missing`)

## Falsifier tails (real output)

1. xaas_test round-trip (migrations recorded): `mix ecto.rollback --step 4` → green;
   `mix ecto.migrate` → `== Migrated 20261007240000 in 0.1s`; repeat `mix ecto.migrate` → `Migrations already up`.
2. xaas_dev-state simulation: `createdb -T xaas_test xaas_test_w971b`, `DELETE 4` schema_migrations rows (objects present, versions absent — exact hazard state), `MIX_TEST_PARTITION=_w971b mix ecto Migrate`:
   - Before fix (mutation): `ERROR 42701 (duplicate_column) column "capability_class" of relation "scratch DB ... already exists`
   - After fix: all four migrate; `schema_migrations` count of the four versions = `4`
   - Mutation: reverting 210000's guard → `ERROR 42701 (duplicate_column) ... already exists` (witnessed); guard restored → migrate green.
3. Full suite `mix test`: three runs, each blocked at compile/type-check by a
   different concurrent lane's mid-edit file — run 1 `freeze_window_active_gate_test.exs` (passes alone: `5 passed`),
   run 2 `multitenancy_deepening_test.exs` (unclosed delimiter, another lane mid-write),
   run 3 `eu_ai_act/title_vi_xiii_test.exs` (type check failure, not a W971b file).
   All W971b-scoped verification (migrations) green; full-suite tail is
   integration-lane work, not attributable to the four migration files.

## Standing

- 111457/210000/220000: replay-safe (up and down) — ALIVE on both DB states
  (objects-present/versions-absent, and clean replay).
- 120000: unchanged; already idempotent by construction (`create_if_not_exists` + idempotent DELETE).
- Non-goal recorded: fixing xaas_dev itself (currently has neither objects nor
  versions — its next `mix ecto.migrate` already applies all four cleanly).

## Triage appendix (W981n, 2026-10-07)

W981n cross-checked this receipt's four versions against the working tree
(receipt: `w981n-migration-triage.md`):

- 111457 and 120000 are present, untracked, and match this receipt's guarded
  versions — ownership confirmed, no BLOCKED(artifact-missing). Note: line 12
  of this receipt has a path typo for 120000 (`priv/repo/` — actual
  `priv/repo/migrations/`).
- 210000/220000 tracked at HEAD, unchanged.
- The third untracked migration, `20261007250000_add_org_id_to_billing_approval_tables.exs`,
  is NOT W971b's — its moduledoc claims lane W970a (SPEC-07, W729-GAP-3);
  no W970a/W975b receipt exists on disk and `w905-design-gap-specs.md`
  attributes SPEC-07 to W975b, so its ownership is UNVERIFIED and its up/down
  are unguarded (the exact replay-hazard class W971b fixed, if the standard
  applies).
