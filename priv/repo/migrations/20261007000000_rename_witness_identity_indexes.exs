defmodule Xaas.Repo.Migrations.RenameWitnessIdentityIndexes do
  @moduledoc """
  Align the witness identity-constraint index names with the names Ash
  derives from the resource identities, so duplicate creates surface as a
  typed `Ash.Error.Invalid` (Ash.Changeset unique-constraint refusal)
  instead of `Ash.Error.Unknown` wrapping the raw `Ecto.ConstraintError`.

  - `witness_certified_receipts_subject_payload_hash_hex_index` (Ecto's
    column-derived name) → `witness_certified_receipts_unique_subject_payload_index`
    (Ash's derived name for identity `:unique_subject_payload` on
    `Xaas.Witness.CertifiedReceipt`).
  - `witness_verification_keys_kid_index` →
    `witness_verification_keys_unique_kid_index` (identity `:unique_kid`
    on `Xaas.Witness.VerificationKey`).

  Each rename is a guarded no-op when the target name already exists
  (fresh test/CI databases created from `20261005000000` are re-aligned
  by the same guards).
  """

  use Ecto.Migration

  @rename_receipt_index """
  DO $$
  BEGIN
    IF EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE indexname = 'witness_certified_receipts_subject_payload_hash_hex_index'
    ) THEN
      ALTER INDEX witness_certified_receipts_subject_payload_hash_hex_index
        RENAME TO witness_certified_receipts_unique_subject_payload_index;
    END IF;
  END
  $$;
  """

  @rename_key_index """
  DO $$
  BEGIN
    IF EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE indexname = 'witness_verification_keys_kid_index'
    ) THEN
      ALTER INDEX witness_verification_keys_kid_index
        RENAME TO witness_verification_keys_unique_kid_index;
    END IF;
  END
  $$;
  """

  def up do
    execute(@rename_receipt_index)
    execute(@rename_key_index)
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'witness_certified_receipts_unique_subject_payload_index'
      ) THEN
        ALTER INDEX witness_certified_receipts_unique_subject_payload_index
          RENAME TO witness_certified_receipts_subject_payload_hash_hex_index;
      END IF;
    END
    $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 from pg_indexes
        WHERE indexname = 'witness_verification_keys_unique_kid_index'
      ) THEN
        ALTER INDEX witness_verification_keys_unique_kid_index
          RENAME TO witness_verification_keys_kid_index;
      END IF;
    END
    $$;
    """)
  end
end
