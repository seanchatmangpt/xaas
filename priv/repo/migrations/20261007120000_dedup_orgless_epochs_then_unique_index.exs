defmodule Xaas.Repo.Migrations.DedupOrglessEpochsThenUniqueIndex do
  @moduledoc """
  Lane W804, FK remediation by lane W982c — repair step for W752 blocker
  F2 (duplicate org-less `(run_id, cycle)` rows in `ultracode_epochs`
  make the W737 partial unique index migration, 20261007010000, fail on
  `xaas_dev`) AND for the W890 blocker: the original W804 dedup DELETE was
  FK-refused on real `xaas_dev` because `ultracode_receipts` rows
  reference the duplicate epochs it must remove
  (`ultracode_receipts_epoch_id_fkey`, 503 on every fresh e2e boot).

  ## FK children (enumerated via real pg_constraint inspection, 2026-10-07,
  ## identical on xaas_dev and xaas_test)

  Exactly ONE foreign key references `ultracode_epochs`:

  - `ultracode_receipts.epoch_id`
    (`ultracode_receipts_epoch_id_fkey`, ON DELETE NO ACTION default)

  (The reverse-direction FK — `ultracode_epochs.run_id ->
  ultracode_runs` — is a parent edge, not a child; dedup never deletes
  runs, so it is out of scope.)

  ## Fix: reparent-before-delete

  Before deleting each doomed duplicate epoch, its `ultracode_receipts`
  rows are REPARENTED to the surviving epoch of the same `(run_id,
  cycle)` group. The receipt therefore keeps referencing the epoch of
  record (the survivor) — zero orphans, zero deletions of receipts.

  ## Order-safe pair

  This migration must be run AFTER 20261007010000 is pending (it is the
  very next migration in the tree relative to W737's). Because it dedups
  BEFORE creating the index, the pair is order-safe in both directions:

  - If 20261007010000 already applied on a clean DB, this migration's
    dedup is a no-op (nothing to delete; nothing to reparent; the
    partial unique index would have refused duplicates at insert time)
    and the guarded `create_if_not_exists` is a no-op.
  - If 20261007010000 FAILED (the xaas_dev situation: duplicates present,
    index creation raised), the index does not exist, this migration
    reparents + deletes the duplicates, then creates the index
    successfully. The operator re-runs `mix ecto.migrate` once after this
    migration lands; the failed 20261007010000 has no recorded version
    and re-runs first, also succeeding (its `create_if_not_exists`
    tolerates this module having created it already — and if this module
    runs first, W737's `create_if_not_exists` still tolerates it).

  ## Keep-rule (documented, deterministic, unchanged from W804)

  For each org-less `(run_id, cycle)` group, KEEP the row with the
  earliest `inserted_at` (the first-inserted epoch is the canonical
  lifecycle row; later duplicates are the defect the W737 identity was
  designed to refuse). Ties on `inserted_at` break to the lexicographically
  smallest `id` (UUID v7-ish ordering — deterministic, no silent
  arbitrary pick). All later rows in the group are DELETED after their
  receipts are reparented, including any that carry lease/completion
  state — the kept earliest row is the row the app treats as the epoch
  of record. Org-scoped rows (`org_id IS NOT NULL`) are never touched:
  they are covered by the pre-existing three-column
  `UNIQUE (org_id, run_id, cycle)` index.

  Idempotent in both directions: on a DB with no org-less duplicates the
  reparent affects 0 rows and the DELETE affects 0 rows; `down` only
  drops the index (deduped data is not fabricated back).
  """

  use Ecto.Migration

  @index_name "ultracode_epochs_orgless_run_cycle_index"

  @doc """
  Statement 1 of the FK-safe dedup: reparent every `ultracode_receipts`
  row whose epoch is a doomed org-less duplicate to that group's
  survivor. Exposed (with `delete_sql/0`) for the Chicago court
  (`test/xaas/ultracode/dedup_orgless_epochs_migration_court_test.exs`)
  so the court executes the EXACT SQL the migration runs (no copy-drift).

  Split into two SEPARATE statements deliberately: within one Postgres
  statement, all parts (main query + data-modifying CTEs) read the same
  snapshot, so a sibling CTE's UPDATE is not visible to the outer
  DELETE's FK trigger — witnessed as a real `ultracode_receipts_epoch_id_fkey`
  violation when this was first written as one CTE statement (court
  tail, W982c).
  """
  def reparent_sql do
    """
    UPDATE ultracode_receipts r
    SET epoch_id = survivor.survivor_id
    FROM (
      SELECT
        e.id AS doomed_id,
        first_value(e.id) OVER (
          PARTITION BY e.run_id, e.cycle
          ORDER BY e.inserted_at ASC, e.id ASC
        ) AS survivor_id
      FROM ultracode_epochs e
      WHERE e.org_id IS NULL
        AND EXISTS (
          SELECT 1 FROM ultracode_epochs e2
          WHERE e2.org_id IS NULL
            AND e2.run_id = e.run_id
            AND e2.cycle = e.cycle
            AND e2.id <> e.id
        )
    ) survivor
    WHERE r.epoch_id = survivor.doomed_id
    """
  end

  @doc """
  Statement 2 of the FK-safe dedup: delete the doomed duplicates (every
  org-less epoch that is not its group's keep-row: earliest inserted_at,
  tie-break smallest id). Run AFTER `reparent_sql/0` — see its @doc.
  """
  def delete_sql do
    """
    DELETE FROM ultracode_epochs e
    USING (
      SELECT
        id,
        row_number() OVER (
          PARTITION BY run_id, cycle
          ORDER BY inserted_at ASC, id ASC
        ) AS rn
      FROM ultracode_epochs
      WHERE org_id IS NULL
    ) ranked
    WHERE e.id = ranked.id
      AND ranked.rn > 1
    """
  end

  def up do
    # --- BEFORE-effect: reparent + dedup org-less (run_id, cycle) dups -
    # Keep earliest inserted_at, tie-break smallest id. Receipts of doomed
    # rows are reparented to the survivor BEFORE the delete (FK-safe;
    # two statements — see reparent_sql/0's @doc for why not one CTE).
    execute(reparent_sql())
    execute(delete_sql())

    # --- Guarded index creation (matches W737's 20261007010000) --------
    create_if_not_exists(
      unique_index(:ultracode_epochs, [:run_id, :cycle],
        name: @index_name,
        where: "org_id IS NULL"
      )
    )
  end

  def down do
    # Dropping the index is safe and reversible; the deleted duplicate
    # rows are NOT resurrected (down restores schema, not fabricated data).
    drop_if_exists(index(:ultracode_epochs, [:run_id, :cycle], name: @index_name))
  end
end
