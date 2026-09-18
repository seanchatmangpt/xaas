defmodule Xaas.Ultracode.Validations.AtMostOneActiveEpoch do
  @moduledoc """
  Real `Ash.Resource.Validation` enforcing `AtMostOneActiveEpoch(run)`.

  Not expressible as a plain `identities do` block (the constraint is
  partial: unique only among rows where `state == :running`), so this is
  the application-level pre-flight half of the invariant -- a real
  `Ash.exists?/2` query against sibling `Epoch` rows for the same
  `run_id`, refusing the transition if another epoch on that run is
  already `:running`.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    run_id =
      Ash.Changeset.get_attribute(changeset, :run_id) ||
        Ash.Changeset.get_data(changeset, :run_id)

    this_id = Ash.Changeset.get_data(changeset, :id)

    already_active? =
      Xaas.Ultracode.Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run_id and state == :running)
      |> Ash.Query.filter(is_nil(^this_id) or id != ^this_id)
      |> Ash.exists?(authorize?: false)

    if already_active? do
      {:error,
       Ash.Error.Changes.InvalidChanges.exception(message: "run already has an active epoch")}
    else
      :ok
    end
  end
end
