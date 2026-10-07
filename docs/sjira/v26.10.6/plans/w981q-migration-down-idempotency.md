# W981q — Migration down/ idempotency hardening receipt

Lane: W981q, xaas v26.10.6 campaign, branch `feat/playwright-surface` (no commit made —
diff left in tree for coordinator integration).

## Subject (exact)

- Migration: `priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs`
  (W971b's version, timestamp unchanged)
- Court: `test/xaas/migrations/w981q_add_ash_onetime_logical_partitions_replay_test.exs`
  (new file)

## O/O*

From W981n's triage (`docs/sjira/v26.10.6/plans/w981n-migration-triage.md`): W971b's
migration up/ was already replay-safe, but down/ had unguarded `DROP CONSTRAINT` /
`DROP COLUMN`. A fresh replay of the dev db (xaas_dev, W786/W804 operator path) that never
ran up/ would crash on down/. Operator direction: harden ONLY down/, same if-exists guard
idiom as up/, do not rename the version, leave the 120000/250000 migrations alone.

## μ / diff (handwritten; no generator surface for migrations)

1. **down/ guard wrap**: the non-global-claims `DO $guard$` block now runs only when
   `column_exists?("ash_onetime_idempotency_claims", "logical_partition")` — on a fresh
   schema the DO block would itself crash on the missing column.
2. **`restore_global_collision/3` guarded**: drops the logical collision constraint only
   `if constraint_exists?(table, current_name)`; skips the legacy re-`ADD` when the legacy
   constraint already exists (fresh replay). Unchanged when run from the upped state.
   Same behavior as before on the normal path.
3. **`drop_partition_column/1` helper**: `DROP COLUMN logical_partition` runs only
   `if column_exists?/2`. Same idiom as up/'s `add_partition_column/1` (W971b style).

Up/ untouched. Timestamp unchanged. 120000/250000 migrations untouched.

## Court (real Postgres, no mocks)

`Xaas.Migrations.AddAshOnetimeLogicalPartitionsReplayTest` — exercises the real migration
through the real `Ecto.Migrator` runner (`{version, module}` target form,
`migration_lock: false`) against a dedicated non-sandbox repo (`W981qRawRepo`, real
autocommitting transactions) on `xaas_test`. Legs:

- (a) up replay on the already-upped schema (guards no-op);
- (b) real down: columns dropped, legacy 3-column unique constraints restored exactly;
- (c) **down AGAIN on the downed schema** — the pre-hardening crash state — guards no-op;
- (d) final up restores the W786 end-state; catalog asserted after every leg.

Version bookkeeping (`schema_migrations` delete/insert) is committed through the raw repo
because the migrator reads committed state; an `on_exit` recover hook restores the upped
end-state after any crash mid-leg.

## Commands + exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981q mix test \
  test/xaas/migrations/w981q_add_ash_onetime_logical_partitions_replay_test.exs \
  test/xaas/schema_migration_consistency_test.exs
# run1 exit=0, "7 passed"   (1 replay-leg court + 6 W846 consistency tests)
# run2 exit=0, "7 passed"   (×2 as directed)
```

Post-run catalog check (psql): `logical_partition` present on all ash_onetime tables;
`schema_migrations` has 20261007111457 recorded. End-state restored.

## Transport failures / boundary notes

- `Ecto.Migrator.run(repo, [file_path], ...)` treats a bare file path as a DIRECTORY
  (wildcard glob matches nothing) and silently returns `[]` — the `{version, module}`
  target form is required for a single-migration runner replay. Boundary learning.
- The sandbox's never-committing transaction hides the migrator's schema_migrations
  writes and row-lock-blocks committed bookkeeping — migration-runner courts need a
  non-sandbox repo. Boundary learning (reusable for future migration courts).
- Session-level disk ENOSPC occurred mid-run; emergency reclaim freed ~81 GB (snapshots/
  caches); no lane data lost. `_build-laneW981q` (449 MB) left in place for the
  coordinator (verify reuse), per the lane-lease law it must be deleted at integration.

## Standing

ALIVE — down/ hardening witnessed by real replay legs ×2 on real Postgres; normal-path
down/ behavior unchanged (leg b/d assert exact legacy constraint shape after down/up).
Falsifier for this lane: a fresh-schema down/ raising or a guard-less drop executing —
refuted by leg (c) passing twice.

## Replay

```
git diff priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs
mix test test/xaas/migrations/w981q_add_ash_onetime_logical_partitions_replay_test.exs
```
