defmodule Xaas.Sjira.EngineerWorkflow.Codec do
  @moduledoc "Deterministic JSON, digest, and opaque cursor codec for engineer-work projections."

  @spec encode(term()) :: String.t()
  def encode(term), do: Jason.encode!(canonical(term))

  @spec encode_pretty(term()) :: String.t()
  def encode_pretty(term), do: Jason.encode!(canonical(term), pretty: true) <> "\n"

  @spec digest(term()) :: String.t()
  def digest(term) do
    "sha256:" <> (:crypto.hash(:sha256, encode(term)) |> Base.encode16(case: :lower))
  end

  @spec encode_cursor(map()) :: String.t()
  def encode_cursor(%{} = payload), do: payload |> encode() |> Base.url_encode64(padding: false)

  @spec decode_cursor(String.t()) :: {:ok, map()} | {:refused, :invalid_cursor_encoding, term()}
  def decode_cursor(cursor) when is_binary(cursor) do
    with {:ok, json} <- Base.url_decode64(cursor, padding: false),
         {:ok, %{} = payload} <- Jason.decode(json) do
      {:ok, payload}
    else
      :error -> {:refused, :invalid_cursor_encoding, cursor}
      {:error, reason} -> {:refused, :invalid_cursor_encoding, inspect(reason)}
      {:ok, other} -> {:refused, :invalid_cursor_encoding, other}
    end
  end

  defp canonical(%{} = map) when not is_struct(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Jason.OrderedObject.new()
  end

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  defp canonical(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> canonical()

  defp canonical(atom) when is_atom(atom) and atom not in [true, false, nil],
    do: Atom.to_string(atom)

  defp canonical(other), do: other
end
