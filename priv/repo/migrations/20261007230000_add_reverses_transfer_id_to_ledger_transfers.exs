defmodule Xaas.Repo.Migrations.AddReversesTransferIdToLedgerTransfers do
  @moduledoc """
  W968c / SPEC-27 (W799-GAP-1): make double-reversal a DB constraint, not an
  accident of sufficiency. `reverses_transfer_id` marks the compensating
  transfer minted by the new `:reverse` action on `Xaas.Ledger.Transfer`;
  the unique index backstops the action-level guard at the storage layer.
  Nullable: every ordinary transfer leaves it NULL (and Postgres unique
  indexes treat NULLs as distinct, so ordinary transfers coexist).
  """

  use Ecto.Migration

  def change do
    alter table(:ledger_transfers) do
      add :reverses_transfer_id, :binary
    end

    create unique_index(:ledger_transfers, [:reverses_transfer_id],
             name: :ledger_transfers_reverses_transfer_id_index,
             where: "reverses_transfer_id IS NOT NULL"
           )
  end
end
