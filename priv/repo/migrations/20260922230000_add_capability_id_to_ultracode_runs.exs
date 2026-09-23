defmodule Xaas.Repo.Migrations.AddCapabilityIdToUltracodeRuns do
  use Ecto.Migration

  # Additive and nullable (same shape as add_semantic_bridge/add_court_map):
  # the work order's required capability id, resolved by
  # `Xaas.Ultracode.RecipeWorker` against the operator recipe registry.
  # Existing rows and writers that do not know the column keep working.
  def change do
    alter table(:ultracode_runs) do
      add :capability_id, :text
    end
  end
end
