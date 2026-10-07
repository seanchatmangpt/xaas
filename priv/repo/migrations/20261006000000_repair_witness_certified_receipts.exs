defmodule Xaas.Repo.Migrations.RepairWitnessCertifiedReceipts do
  @moduledoc """
  Corrective migration: some databases (local dev) stamped migration
  20261005000000 while that file had an older, partial column set (no
  `inserted_at`/`updated_at`, `verified_at` as naive timestamp). Brings
  existing installs to the shape the `Xaas.Witness.CertifiedReceipt`
  resource projects. Every statement is a no-op on databases already at
  the current shape (fresh test/CI databases).
  """

  use Ecto.Migration

  @table :witness_certified_receipts

  def up do
    alter table(@table) do
      add_if_not_exists(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("now()")
      )

      add_if_not_exists(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("now()")
      )
    end

    # Older installs typed verified_at as naive timestamp; the resource
    # projects utc_datetime_usec. No-op when already timestamptz.
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'witness_certified_receipts'
          AND column_name = 'verified_at'
          AND data_type = 'timestamp without time zone'
      ) THEN
        ALTER TABLE witness_certified_receipts
          ALTER COLUMN verified_at TYPE timestamptz
          USING verified_at AT TIME ZONE 'UTC';
      END IF;
    END
    $$;
    """)
  end

  def down do
    :ok
  end
end
