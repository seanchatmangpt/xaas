defmodule Xaas.Ocel.Validations.NotSelfReferential do
  @moduledoc """
  Real structural validation: an `Xaas.Ocel.ObjectObject` relation cannot
  relate an object to itself. Not a fabricated causal check -- a plain
  equality guard on the two accepted foreign keys, enforced at admission
  time before any row is written.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    source = Ash.Changeset.get_attribute(changeset, :source_object_id)
    target = Ash.Changeset.get_attribute(changeset, :target_object_id)

    if source && target && source == target do
      {:error,
       field: :target_object_id,
       message: "an object cannot be related to itself (source_object_id == target_object_id)"}
    else
      :ok
    end
  end
end
