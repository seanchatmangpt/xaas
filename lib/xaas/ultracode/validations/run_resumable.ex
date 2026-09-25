defmodule Xaas.Ultracode.Validations.RunResumable do
  @moduledoc """
  Real `Ash.Resource.Validation` guarding `Run.:resume`: refuses (typed
  error, not a silent no-op) resuming a Run that has nothing left to run --
  no currently-active `Epoch` (`:expected`/`:running`) AND its cycle budget
  exhausted (`run.cycle >= run.max_cycles`).

  Without this, such a resume would succeed and then be failed by the very
  next tick (`Xaas.Ultracode.NextEpoch`'s bounded stale recovery lands an
  exhausted Run on `:failed`), making resume a lie the tick exposes one
  minute later. Refusing at the resume action is the honest boundary.

  A Run with a live epoch (stopped mid-epoch) is resumable regardless of
  cycle budget: the epoch, not the budget, is what continues.
  """

  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    run = changeset.data

    {:ok, active_epochs} =
      Xaas.Ultracode.Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id and state in [:expected, :running])
      |> Ash.Query.limit(1)
      |> Ash.read(authorize?: false)

    cond do
      active_epochs != [] ->
        :ok

      run.cycle < run.max_cycles ->
        :ok

      true ->
        {:error,
         Ash.Error.Changes.InvalidChanges.exception(
           message:
             "run #{run.id} is not resumable: no active epoch and cycle budget exhausted " <>
               "(cycle #{run.cycle} >= max_cycles #{run.max_cycles})"
         )}
    end
  end
end
