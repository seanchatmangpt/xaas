defmodule Xaas.Repo.Migrations.AddWitnessTables do
  @moduledoc """
  Tables for the Xaas.Witness certified-receipt surface (lane PW5).
  """

  use Ecto.Migration

  def up do
    create table(:witness_certified_receipts, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :subject, :text, null: false
      add :payload_hash_hex, :text, null: false
      add :algorithm, :text, null: false
      add :signature_hex, :text, null: false
      add :verifying_key_hex, :text, null: false
      add :verified, :boolean, null: false, default: false
      add :verified_at, :utc_datetime_usec
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create unique_index(:witness_certified_receipts, [:subject, :payload_hash_hex])

    create table(:witness_verification_keys, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :kid, :text, null: false
      add :algorithm, :text, null: false
      add :key_material_hex, :text, null: false
      add :created_at, :utc_datetime_usec, null: false
    end

    create unique_index(:witness_verification_keys, [:kid])
  end

  def down do
    drop table(:witness_verification_keys)
    drop table(:witness_certified_receipts)
  end
end
