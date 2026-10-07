# W804 — Epoch dedup + guarded unique index (W752 blocker F2)

Standing: PARTIAL_ALIVE — migration verified on xaas_test by real execution
(dedup keep-rule asserted on real rows, mutation demonstrated, index exists,
version recorded); **operator still must run `mix ecto.migrate` on xaas_dev**.

## Subject

- Repo: /Users/sac/xaas, branch feat/playwright-surface, HEAD a0723bf6
- File: `priv/repo/migrations/20261007120000_dedup_orgless_epochs_then_unique_index.exs`
  (the ONE new file written this lane; not committed — coordinator owns the commit)
- Closes W752 blocker F2: duplicate org-less `(run_id, cycle)` rows in
  `ultracode_epochs` made W737's 20261007010000 raise on xaas_dev.

## What the migration does (order-safe pair)

1. BEFORE-effect dedup: `DELETE ... USING` with `row_number() OVER
   (PARTITION BY run_id, cycle ORDER BY inserted_at ASC, id ASC)` over
   `org_id IS NULL` rows; deletes every `rn > 1` row.
2. `create_if_not_exists` of the partial unique index
   `ultracode_epochs_orgless_run_cycle_index ON ultracode_epochs (run_id, cycle) WHERE org_id IS NULL`.

**Keep-rule (documented in the migration moduledoc):** keep earliest
`inserted_at`, tie-break smallest `id`; org-scoped rows never touched.

Order-safety: on a clean DB the DELETE is a 0-row no-op and
`create_if_not_exists` is a no-op; on the dev failure state (dups present,
index absent) it dedups then creates. If dev's failed 20261007010000 has no
recorded version, the operator's re-run of `mix ecto.migrate` re-runs it
first — both modules are `if_not_exists`-guarded, so either order succeeds.

## Operator command for dev

```bash
cd /Users/sac/xaas
export PATH=$HOME/.asdf/shims:$PATH
MIX_ENV=dev mix ecto.migrate
```

(The failed 20261007010000 has no recorded version on dev — index creation
raised — so it re-runs; then 20261007120000 dedups + creates the index.
Both are `IF NOT EXISTS`-guarded; either order is safe.)

## Verification on xaas_test (real execution, not inspection)

Setup: deleted version 20261007120000 from schema_migrations, dropped the
index, seeded via psql: 1 org-less run + 3 org-less epochs — duplicate group
cycle=1: e002 (state=completed, inserted_at 10:01), e003 (state=failed,
inserted_at 10:00, EARLIEST), plus control row e004 (cycle=2, 10:02).

1. **Mutation demonstrated**: bare
   `CREATE UNIQUE INDEX ... WHERE org_id IS NULL` over the duplicates raised
   `ERROR 23505 (unique_violation) could not create unique index
   "ultracode_epochs_orgless_run_cycle_index"` —
   `Key (run_id, cycle)=(0b5f7c1e-...-00000000d001, 1) is duplicated.`
   (log tail: /tmp/w804_run3.log and inline transcript)
2. **Migration applied** via `Ecto.Migrator.run/4` (all: true) against
   xaas_test. Post-state (real psql output):

```
 id                                   | state    | inserted_at     | cycle
 0b5f7c1e-...-e003 | failed   | 2026-10-07 10:00:00 | 1
 0b5f7c1e-...-e004 | expected | 2026-10-07 10:02:00 | 2
```

   e002 (the later duplicate, 10:01) DELETED; the EARLIEST row (e003,
   10:00) kept — keep-rule asserted on real state. Control row e004
   untouched. Version 20261007120000 recorded in schema_migrations.

   ```
 CREATE UNIQUE INDEX ultracode_epochs_orgless_run_cycle_index ON public.ultracode_epochs USING btree (run_id, cycle) WHERE (org_id IS NULL)
   ```

3. **W737 refusal court**: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW804 mix
   test test/xaas/ultracode/run_receipt_deepening_test.exs` →

```
Finished in 1.1 seconds (1.1s async, 0.00s sync)
Result: 10 passed
```

4. Post-verification cleanup: seeded rows deleted from xaas_test (epochs +
   run); DB left in correctly migrated state (version recorded, index
   present). `_build-laneW804` left on disk — see Transport failures.

## Transport failures / notes for coordinator

- A transient untracked file
  `lib/xaas/operations/validations/incident_resolved_is_terminal.ex`
  (another lane's in-flight write against a nonexistent
  `Ash.Changeset.OriginalDataNotLoaded` struct) broke full compiles of the
  shared tree for ~20 minutes; the owning lane removed it and compiles
  succeeded. No action needed.
- xaas_test was concurrently reset by another lane mid-verification
  (seeded rows vanished; version recorded without my run); I re-seeded via
  psql and re-ran. Final state re-verified above.
- `rm -rf _build-laneW804` was permission-denied in this lane; the lane
  build root remains for coordinator cleanup per lane lease law.

## Falsifiers (both run, both killed the null hypothesis)

- F1 (dedup keep-rule wrong): survived rows were not the earliest → KILLED:
  earliest row kept, later deleted, control untouched.
- F2 (mutation vacuous): bare index over duplicates passes → KILLED: 23505
  unique_violation witnessed on real DB.
