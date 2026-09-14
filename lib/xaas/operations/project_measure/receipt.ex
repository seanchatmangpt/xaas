defmodule Xaas.Operations.ProjectMeasure.Receipt do
  @moduledoc false

  @algorithm "sha256"
  @canonicalization "sorted-json-v1"
  @replay "remove receipt, canonicalize recursively, recompute sha256, require exact equality"

  def attach(observation) when is_map(observation) do
    observation = Map.delete(observation, "receipt")

    Map.put(observation, "receipt", %{
      "algorithm" => @algorithm,
      "canonicalization" => @canonicalization,
      "observation_digest" => digest(observation),
      "replay" => @replay
    })
  end

  def verify(
        %{
          "receipt" => %{
            "algorithm" => @algorithm,
            "canonicalization" => @canonicalization,
            "observation_digest" => expected
          }
        } = payload
      )
      when is_binary(expected) do
    digest(Map.delete(payload, "receipt")) == expected
  end

  def verify(_), do: false

  def digest(value) do
    value
    |> canonical_json()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  def canonical_json(value) when is_map(value) do
    body =
      value
      |> Enum.map(fn {key, item} -> {to_string(key), item} end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join(",", fn {key, item} ->
        Jason.encode!(key) <> ":" <> canonical_json(item)
      end)

    "{" <> body <> "}"
  end

  def canonical_json(value) when is_list(value) do
    "[" <> Enum.map_join(value, ",", &canonical_json/1) <> "]"
  end

  def canonical_json(value)
      when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value) do
    Jason.encode!(value)
  end
end
