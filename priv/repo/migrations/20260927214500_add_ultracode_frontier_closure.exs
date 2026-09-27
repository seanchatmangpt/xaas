defmodule Xaas.Repo.Migrations.AddUltracodeFrontierClosure do
  use Ecto.Migration

  def up do
    alter table(:ultracode_runs) do
      add :frontier, :map, null: false, default: fragment("'{}'::jsonb")
      add :frontier_digest, :text
      add :frontier_size, :bigint, null: false, default: 0
      add :frontier_version, :bigint, null: false, default: 0
      add :frontier_recorded_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:ultracode_runs) do
      remove :frontier_recorded_at
      remove :frontier_version
      remove :frontier_size
      remove :frontier_digest
      remove :frontier
    end
  end
end
