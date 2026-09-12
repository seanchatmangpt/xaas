defmodule Xaas.Actuation.Validations.FrontierEvidence do
  @moduledoc """
  Fails closed on malformed cross-repository FrontierEvidence bundles.

  Absence is allowed so existing deterministic actuation remains unchanged. Once a
  bundle is supplied, however, all four bounded producer classes, their exact
  authority ceilings, and the XaaS-computed bundle digest must validate before an
  ActuationIntent may be admitted.
  """

  use Ash.Resource.Validation

  alias Xaas.Actuation.FrontierEvidence

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    authority = Ash.Changeset.get_attribute(changeset, :authority) || %{}

    case fetch(authority, "frontier_evidence") do
      nil ->
        :ok

      %{} = bundle ->
        case FrontierEvidence.validate_bundle(bundle) do
          :ok -> :ok
          {:error, reason} -> refusal("frontier evidence refused: #{inspect(reason)}")
        end

      _ ->
        refusal("frontier evidence bundle must be a map")
    end
  end

  defp fetch(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end

  defp refusal(message), do: {:error, field: :authority, message: message}
end
