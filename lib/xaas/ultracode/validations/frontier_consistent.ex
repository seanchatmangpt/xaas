defmodule Xaas.Ultracode.Validations.FrontierConsistent do
  @moduledoc """
  Fail-closed validation for Run.:record_frontier.

  The persisted frontier map, digest and pending-work size are one atomic fact.
  No caller may persist a digest/size that does not match the canonical
  Xaas.Ultracode.Frontier interpretation of the supplied map.
  """

  use Ash.Resource.Validation

  alias Xaas.Ultracode.Frontier

  @impl true
  def validate(changeset, _opts, _context) do
    frontier = Ash.Changeset.get_attribute(changeset, :frontier)
    expected_digest = Ash.Changeset.get_attribute(changeset, :frontier_digest)
    expected_size = Ash.Changeset.get_attribute(changeset, :frontier_size)

    case Frontier.admit(frontier) do
      {:ok, snapshot} ->
        if snapshot["digest"] == expected_digest and
             snapshot["pending_work"] == expected_size do
          :ok
        else
          invalid(
            "frontier identity mismatch: expected digest=#{inspect(expected_digest)} " <>
              "size=#{inspect(expected_size)}, canonical digest=#{snapshot["digest"]} " <>
              "size=#{snapshot["pending_work"]}"
          )
        end

      {:error, reason} ->
        invalid("frontier refused: #{inspect(reason)}")
    end
  end

  defp invalid(message) do
    {:error, Ash.Error.Changes.InvalidChanges.exception(message: message)}
  end
end
