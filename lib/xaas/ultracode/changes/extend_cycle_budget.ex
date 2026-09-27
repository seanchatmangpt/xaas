defmodule Xaas.Ultracode.Changes.ExtendCycleBudget do
  @moduledoc """
  Re-arms a frontier-suspended Run with explicit additional cycle headroom.

  The new maximum is at least current cycle + additional_cycles; existing
  larger bounds are preserved. Resumption therefore never shrinks a Run.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    additional = Ash.Changeset.get_argument(changeset, :additional_cycles) || 1
    cycle = Ash.Changeset.get_data(changeset, :cycle) || 0
    current = Ash.Changeset.get_data(changeset, :max_cycles) || 0

    Ash.Changeset.force_change_attribute(
      changeset,
      :max_cycles,
      max(current, cycle + additional)
    )
  end
end
