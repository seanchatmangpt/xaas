defmodule Xaas.Ultracode.Changes.SetFrontierRecordedAt do
  @moduledoc """
  Records the runtime observation time for one admitted frontier snapshot.

  The clock belongs to the persistence boundary, never to a caller-supplied
  frontier payload.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.force_change_attribute(
      changeset,
      :frontier_recorded_at,
      DateTime.utc_now()
    )
  end
end
