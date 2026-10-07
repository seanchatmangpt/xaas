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
        changeset
        |> Ash.Changeset.force_change_attributes(
          amount: original.amount,
          timestamp: DateTime.utc_now(),
          from_account_id: original.to_account_id,
          to_account_id: original.from_account_id,
          reverses_transfer_id: original.id
        )
        |> run_sufficiency(original)
    end
  end

  # W983j (W982i attack-1 fix): the declared TransferSourceSufficiency
  # validation on :reverse is dead code -- it runs before this before_action
  # hook, when from/to_account_id are still nil, so check_sufficiency/1 takes
  # the is_nil -> :ok skip and a compensating mint can drain the original
  # recipient negative. Fix the invariant, not the probe: with the swapped
  # attributes now forced onto the changeset, invoke the same validation
  # explicitly so it sees the real compensating source (the original
  # recipient) and refuses an underfunded reversal with the same typed error
  # the ordinary :transfer action produces. The W785 exemptions
  # (skip_balance_updates context, xaas_ledger.allow_overdraft context)
  # apply unchanged -- no separate overdraft story for :reverse.
  defp run_sufficiency(changeset, _original) do
    case Xaas.Ledger.Validations.TransferSourceSufficiency.validate(changeset, [], []) do
      :ok ->
        changeset

      {:error, opts} ->
        Ash.Changeset.add_error(changeset, opts)
    end
  end

  defp already_reversed?(original_id) do
    Xaas.Ledger.Transfer
    |> Ash.Query.filter(reverses_transfer_id == ^original_id)
    |> Ash.exists?(authorize?: false)
  end
end
