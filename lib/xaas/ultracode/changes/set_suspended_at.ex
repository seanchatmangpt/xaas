defmodule Xaas.Ultracode.Changes.SetSuspendedAt do
  @moduledoc """
  Persists the instant a Run enters :suspended because bounded execution
  ended before closure was proved. The timestamp is historical evidence and
  remains after resume so OCEL can represent the suspension event.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :state) do
      :suspended ->
        Ash.Changeset.force_change_attribute(changeset, :suspended_at, DateTime.utc_now())

      _ ->
        changeset
    end
  end
end
