defmodule Xaas.Repo.Migrations.AddGraphlawEngineRegistry do
  @moduledoc """
  Adds the graphlaw engine-registry projection tables:
  `graphlaw_engine_limits` and `graphlaw_capabilities`.
  """

  use Ecto.Migration

  def up do
    create table(:graphlaw_engine_limits, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :value, :bigint, null: false
      add :scope, :text, null: false
      add :source, :text, null: false
      add :unit, :text, null: false
      add :refusal_name, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:graphlaw_engine_limits, [:name])

    create table(:graphlaw_capabilities, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :algorithm, :text, null: false
      add :profile, :text, null: false
      add :supported_in, {:array, :text}, null: false, default: []

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:graphlaw_capabilities, [:name, :algorithm])
  end

  def down do
    drop table(:graphlaw_capabilities)
    drop table(:graphlaw_engine_limits)
  end
end
