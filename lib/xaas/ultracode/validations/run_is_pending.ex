defmodule Xaas.Ultracode.Validations.RunIsPending do
  @moduledoc """
  Real `Ash.Resource.Validation` guarding `Run.:start`: refuses (typed
  error, not a silent no-op) unless the Run's current `state` is
  `:pending`. Same shape as `Xaas.Ultracode.Validations.
  AtMostOneActiveEpoch` -- an application-level pre-flight check, here
  guarding "start this Run exactly once" rather than "at most one active
  epoch".
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_data(changeset, :state) do
      :pending ->
        :ok

      other ->
        {:error,
         Ash.Error.Changes.InvalidChanges.exception(
           message: "run must be :pending to :start, was #{inspect(other)}"
         )}
    end
  end
end
