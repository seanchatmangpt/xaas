defmodule Xaas.Repo.Migrations.AddSemanticBridgeToUltracodeRuns do
  use Ecto.Migration

  # Additive and nullable: existing rows and writers that do not know the
  # column keep working.
  def change do
    alter table(:ultracode_runs) do
      add :semantic_bridge, :map
    end
  end
end
