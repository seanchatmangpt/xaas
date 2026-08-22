defmodule Xaas.Repo.Migrations.ResolvePendingBacklog20260821 do
  @moduledoc """
  Resolves the final AshCloak token-storage backlog without replaying schema work
  already owned by earlier migrations.

  The original generated migration attempted to recreate three AutoFDE request
  tables and to repeat the platform webhook encryption-column migration. Those
  objects are already created by earlier timestamped migrations, so replaying
  them makes a clean `ecto.migrate` fail with duplicate-object errors.

  `Xaas.Accounts.Token`, however, genuinely requires the
  `encrypted_extra_data :binary` storage column manufactured by AshCloak. This
  migration adds that column and refuses to destroy a populated legacy
  `extra_data` column. A database containing legacy plaintext token metadata must
  be backfilled through an explicitly authorized application-level encryption
  procedure before this migration may remove the plaintext column.
  """

  use Ecto.Migration

  def up do
    alter table(:tokens) do
      add :encrypted_extra_data, :binary
    end

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM tokens
        WHERE extra_data IS NOT NULL
      ) THEN
        RAISE EXCEPTION 'REFUSED[TOKEN_CLOAK_BACKFILL_REQUIRED]: tokens.extra_data contains legacy plaintext values';
      END IF;
    END
    $$;
    """)

    alter table(:tokens) do
      remove :extra_data
    end
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM tokens
        WHERE encrypted_extra_data IS NOT NULL
      ) THEN
        RAISE EXCEPTION 'REFUSED[TOKEN_CLOAK_DOWNGRADE_DATA_PRESENT]: encrypted token metadata exists';
      END IF;
    END
    $$;
    """)

    alter table(:tokens) do
      add :extra_data, :map
      remove :encrypted_extra_data
    end
  end
end
