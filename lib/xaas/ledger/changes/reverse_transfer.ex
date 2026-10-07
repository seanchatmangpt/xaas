defmodule Xaas.Ledger.Changes.ReverseTransfer do
  @moduledoc """
  W968c / SPEC-27 (W799-GAP-1): body of `Xaas.Ledger.Transfer :reverse`.

  The mechanism is unchanged from the disclosed round trip (w799
  reversal-deepening): a compensating transfer with `from_account_id`/
  `to_account_id` swapped, same amount, subject to the same W762
  sufficiency validation. What this change adds is the reversal-aware
  guards the sufficiency accident never provided:

  1. unknown `transfer_id` -> typed refusal (field `:transfer_id`);
  2. a compensating transfer already exists for the original
     (`reverses_transfer_id` match, read live from the real tables) ->
     typed refusal naming the original transfer id;
  3. the minted compensating transfer carries `reverses_transfer_id`,
     with the DB unique index
     (`ledger_transfers_reverses_transfer_id_index`) as the constraint
     backstop, so double-reversal is never admitted regardless of
     balances.
  """

  use Ash.Resource.Change
  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &resolve_and_swap/1)
  end

  defp resolve_and_swap(changeset) do
    transfer_id = Ash.Changeset.get_argument(changeset, :transfer_id)

    original =
      Xaas.Ledger.Transfer
      |> Ash.Query.filter(id == ^transfer_id)
      |> Ash.read_one!(authorize?: false)

    cond do
      is_nil(original) ->
        Ash.Changeset.add_error(
          changeset,
          field: :transfer_id,
          message: "no such transfer to reverse"
        )

      already_reversed?(original.id) ->
        Ash.Changeset.add_error(
          changeset,
          field: :transfer_id,
          message: "transfer already reversed",
          vars: %{original_transfer_id: original.id}
        )

      true ->
        # before_action runs post-validation, so attribute writes here must
        # be forced (the originals are read from a trusted row, never user
        # input, so forcing is lawful and documented).
        Ash.Changeset.force_change_attributes(changeset,
          amount: original.amount,
          timestamp: DateTime.utc_now(),
          from_account_id: original.to_account_id,
          to_account_id: original.from_account_id,
          reverses_transfer_id: original.id
        )
    end
  end

  defp already_reversed?(original_id) do
    Xaas.Ledger.Transfer
    |> Ash.Query.filter(reverses_transfer_id == ^original_id)
    |> Ash.exists?(authorize?: false)
  end
end
