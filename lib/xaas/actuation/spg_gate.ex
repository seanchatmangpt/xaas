defmodule Xaas.Actuation.SpgGate do
  @moduledoc """
  Fail-closed Semantic Procedural Graph identity admission for consequential DO.

  The gate only validates identity and admission state. It grants no authority;
  the existing XaaS Actuation/BRCE authority path remains exclusive.
  """

  @required [:graph_id, :graph_version, :node_id, :edge_id]

  @type identity :: %{
          required(:graph_id) => String.t(),
          required(:graph_version) => String.t(),
          required(:node_id) => String.t(),
          required(:edge_id) => String.t(),
          required(:state) => :admitted | String.t(),
          optional(:projection_family) => String.t()
        }

  @spec admit(term()) :: {:ok, map()} | {:error, atom()}
  def admit(identity) when is_map(identity) do
    normalized = normalize(identity)

    cond do
      Enum.any?(@required, &(not non_empty?(Map.get(normalized, &1)))) ->
        {:error, :spg_identity_required}

      Map.get(normalized, :state) not in [:admitted, "ADMITTED", "ADMITTED"] ->
        {:error, :spg_not_admitted}

      true ->
        {:ok, Map.take(normalized, @required ++ [:projection_family, :state])}
    end
  end

  def admit(_), do: {:error, :spg_identity_required}

  @spec fingerprint_token(map()) :: tuple()
  def fingerprint_token(identity) do
    {
      identity.graph_id,
      identity.graph_version,
      identity.node_id,
      identity.edge_id,
      Map.get(identity, :projection_family)
    }
  end

  defp normalize(identity) do
    Map.new(identity, fn
      {key, value} when is_binary(key) ->
        atom =
          case key do
            "graph_id" -> :graph_id
            "graph_version" -> :graph_version
            "node_id" -> :node_id
            "edge_id" -> :edge_id
            "projection_family" -> :projection_family
            "state" -> :state
            _ -> key
          end

        {atom, value}

      pair ->
        pair
    end)
  end

  defp non_empty?(value), do: is_binary(value) and byte_size(value) > 0
end
