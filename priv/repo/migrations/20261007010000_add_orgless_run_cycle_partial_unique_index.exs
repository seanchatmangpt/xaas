defmodule Xaas.Repo.Migrations.AddOrglessRunCyclePartialUniqueIndex do
  @moduledoc """
  Lane W737 — closes the identity NULL-distinctness gap W717 documented.

  `Xaas.Ultracode.Epoch`'s `identity(:unique_run_cycle, [:run_id, :cycle])`
  is backed by Postgres `UNIQUE (org_id, run_id, cycle)` (org_id was added
  by the 20260917230922 multitenancy migration). Postgres UNIQUE treats
  NULLs as distinct, so for org-less Runs — every internal fixture and
  unscoped caller — a duplicate `(run_id, cycle)` epoch was ACCEPTED, not
  refused. This adds the partial unique index that restores the identity's
  org-less half:

      CREATE UNIQUE INDEX ... ON ultracode_epochs (run_id, cycle) WHERE org_id IS NULL

  Org-scoped rows are untouched: the existing three-column unique index
  still fires for real `org_id` values.
  """

  use Ecto.Migration

  @index_name "ultracode_epochs_orgless_run_cycle_index"

  def up do
    create_if_not_exists(
      unique_index(:ultracode_epochs, [:run_id, :cycle],
        name: @index_name,
        where: "org_id IS NULL"
      )
    )
  end

  def down do
    drop_if_exists(index(:ultracode_epochs, [:run_id, :cycle], name: @index_name))
  end
end
