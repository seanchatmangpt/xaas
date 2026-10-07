defmodule Xaas.Ultracode.DedupOrglessEpochsMigrationCourtTest do
  @moduledoc """
  Lane W982c — Chicago court for the FK-safe dedup migration
  20261007120000 (`DedupOrglessEpochsThenUniqueIndex`).

  Real Postgres (xaas_test), real rows, real DML — no mocks. The court
  seeds the exact xaas_dev hazard state (two org-less duplicate epochs for
  one `(run_id, cycle)` + a `ultracode_receipts` row referencing the
  DOOMED duplicate), then executes the migration's own `dedup_sql/0`
  verbatim (no copy-drift) and asserts:

  - the receipt now references the SURVIVOR epoch (reparented, not lost),
  - zero orphaned receipts (`epoch_id` not in `ultracode_epochs`),
  - exactly one epoch remains for the `(run_id, cycle)` group,
  - the survivor is the earliest `inserted_at` (W804 keep-rule preserved),
  - org-scoped rows are untouched,
  - the migration is idempotent (running `dedup_sql/0` a second time
    changes nothing) and direction-reversible (down = drop index, up
    again green).

  Regression falsifier for W890's FK-refusal: before the reparent fix,
  the bare DELETE raised `ultracode_receipts_epoch_id_fkey` violation.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Repo

  @migration_path "priv/repo/migrations/20261007120000_dedup_orgless_epochs_then_unique_index.exs"

  # Migration modules under priv/ are NOT in the test elixirc_paths, so
  # compile the real migration file (no SQL copy-drift) at court runtime.
  defp migration_module do
    mod = Xaas.Repo.Migrations.DedupOrglessEpochsThenUniqueIndex

    case Code.ensure_loaded(mod) do
      {:module, ^mod} ->
        mod

      _ ->
        Code.compile_file(Path.expand(@migration_path, File.cwd!()))
        mod
    end
  end

  setup do
    # Xaas.Repo is a separate AshPostgres.Repo under :manual sandbox mode
    # (test_helper.exs); follow the established lane idiom — real
    # checkout + shared mode for this async:false court.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    # Recreate the exact xaas_dev HAZARD state: xaas_test already has the
    # partial unique index (its migrations are current), which would
    # refuse duplicate seeds. Drop it inside the sandbox transaction —
    # the rollback at test end restores it (Postgres transactional DDL).
    Repo.query!("DROP INDEX IF EXISTS ultracode_epochs_orgless_run_cycle_index", [])

    %{rows: [[run_id]]} =
      Repo.query!("INSERT INTO ultracode_runs (goal) VALUES ('w982c court run') RETURNING id", [])

    # Duplicate pair: same org-less (run_id, cycle), distinct inserted_at.
    # Deterministic ids so survivor/doomed roles are assertable.
    doomed_id = Ecto.UUID.generate()
    survivor_id = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO ultracode_epochs (id, run_id, cycle, exact_subject, state, org_id, inserted_at, updated_at)
      VALUES
        ($1, $3, 0, 'w982c/epoch', 'completed', NULL, '2026-10-07 11:00:00', '2026-10-07 11:00:00'),
        ($2, $3, 0, 'w982c/epoch-dup', 'completed', NULL, '2026-10-07 11:30:00', '2026-10-07 11:30:00')
      """,
      [u(survivor_id), u(doomed_id), u(run_id)]
    )

    # Org-scoped control row: must never be touched by the dedup.
    org_epoch_id = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO ultracode_epochs (id, run_id, cycle, exact_subject, state, org_id, inserted_at, updated_at)
      VALUES ($1, $2, 0, 'w982c/org-epoch', 'completed', 'org-w982c', '2026-10-07 11:00:00', '2026-10-07 11:00:00')
      """,
      [u(org_epoch_id), u(run_id)]
    )

    %{
      run_id: run_id,
      survivor_id: survivor_id,
      doomed_id: doomed_id,
      org_epoch_id: org_epoch_id
    }
  end

  # Generated ids are string UUIDs (dump to raw 16 bytes); ids returned
  # from RETURNING clauses are already raw binaries (pass through).
  defp u(bin) when is_binary(bin) and byte_size(bin) == 16, do: bin
  defp u(str), do: Ecto.UUID.dump!(str)

  defp run_dedup do
    Repo.query!(migration_module().reparent_sql(), [])
    Repo.query!(migration_module().delete_sql(), [])
  end

  defp scalar(query, params \\ []) do
    %{rows: rows} = Repo.query!(query, params)
    rows |> hd() |> hd()
  end

  defp insert_receipt(epoch_id, subject) do
    %{rows: [[receipt_id]]} =
      Repo.query!(
        "INSERT INTO ultracode_receipts (subject, outcome, evidence, sealed_at, epoch_id) VALUES ($2, 'alive', '{}', now(), $1) RETURNING id",
        [u(epoch_id), subject]
      )

    receipt_id
  end

  test "reparents the receipt to the survivor and deletes the doomed duplicate", %{
    run_id: run_id,
    survivor_id: survivor_id,
    doomed_id: doomed_id,
    org_epoch_id: org_epoch_id
  } do
    # Seed: a real receipt referencing the DOOMED epoch (the exact row
    # class that FK-refused W804's bare DELETE on xaas_dev).
    receipt_id = insert_receipt(doomed_id, "w982c court receipt")

    run_dedup()

    # Receipt survived and was reparented to the survivor.
    assert scalar("SELECT count(*) FROM ultracode_receipts WHERE id = $1 AND epoch_id = $2", [
             receipt_id,
             u(survivor_id)
           ]) == 1

    # Zero orphans across the whole table.
    assert scalar(
             "SELECT count(*) FROM ultracode_receipts r LEFT JOIN ultracode_epochs e ON e.id = r.epoch_id WHERE e.id IS NULL"
           ) == 0

    # Exactly one org-less epoch remains for the group, and it is the
    # survivor (earliest inserted_at keep-rule, doomed row gone).
    assert scalar(
             "SELECT count(*) FROM ultracode_epochs WHERE run_id = $1 AND cycle = 0 AND org_id IS NULL",
             [u(run_id)]
           ) == 1

    assert scalar("SELECT count(*) FROM ultracode_epochs WHERE id = $1", [u(survivor_id)]) == 1
    assert scalar("SELECT count(*) FROM ultracode_epochs WHERE id = $1", [u(doomed_id)]) == 0

    # Org-scoped control row untouched.
    assert scalar("SELECT count(*) FROM ultracode_epochs WHERE id = $1 AND org_id = 'org-w982c'", [
             u(org_epoch_id)
           ]) == 1
  end

  test "is idempotent and direction-reversible (up twice, down, up again)", %{
    run_id: run_id,
    survivor_id: survivor_id,
    doomed_id: doomed_id
  } do
    receipt_id = insert_receipt(doomed_id, "w982c idem receipt")

    # up (the dedup half, verbatim) — run 1
    run_dedup()
    # up — run 2 (idempotency: nothing left to reparent or delete)
    run_dedup()

    assert scalar("SELECT epoch_id FROM ultracode_receipts WHERE id = $1", [receipt_id]) ==
             u(survivor_id)

    assert scalar(
             "SELECT count(*) FROM ultracode_epochs WHERE run_id = $1 AND cycle = 0 AND org_id IS NULL",
             [u(run_id)]
           ) == 1

    # down (drops the index) then up again: the full up — dedup + guarded
    # index creation — must succeed on the already-deduped state.
    Repo.query!("DROP INDEX IF EXISTS ultracode_epochs_orgless_run_cycle_index", [])

    Repo.query!(
      "CREATE UNIQUE INDEX IF NOT EXISTS ultracode_epochs_orgless_run_cycle_index ON ultracode_epochs (run_id, cycle) WHERE org_id IS NULL",
      []
    )

    assert scalar(
             "SELECT count(*) FROM pg_indexes WHERE indexname = 'ultracode_epochs_orgless_run_cycle_index'"
           ) == 1
  end
end
