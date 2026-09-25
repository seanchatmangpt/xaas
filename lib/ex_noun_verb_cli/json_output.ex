defmodule ExNounVerbCli.JsonOutput do
  @moduledoc """
  Wraps a dispatch result (`{:ok, term}` or `{:error, ExNounVerbCli.Error.t()}`)
  into a small, stable, Jason-encodable envelope, and provides a helper to
  encode that envelope straight to a JSON string.

  Envelope shape:

      %{"status" => "ok", "result" => <term>}
      %{"status" => "error", "error" => %{"code" => <code>, "message" => <msg>, "detail" => <detail>}}
  """

  alias ExNounVerbCli.Error

  @doc """
  Builds the Jason-encodable envelope map for a dispatch result.
  """
  @spec encode(:ok, term()) :: map()
  @spec encode(:error, Error.t()) :: map()
  def encode(:ok, result) do
    %{"status" => "ok", "result" => result}
  end

  def encode(:error, %Error{} = error) do
    %{
      "status" => "error",
      "error" => %{
        "code" => Atom.to_string(error.code),
        "message" => error.message,
        "detail" => sanitize(error.detail)
      }
    }
  end

  # `Error.t()`'s detail is documented as free-form, so it can carry terms
  # Jason cannot encode (e.g. handler-supplied context or OptionParser's
  # {flag, value} tuples). The library's standing invariant is that the
  # envelope ALWAYS serializes -- including on the error path, where a
  # Jason crash would take the whole escript process down instead of
  # printing the failure envelope -- so non-encodable detail terms are
  # defensively normalized here rather than trusted to be encodable.
  defp sanitize(detail) when is_map(detail) do
    Map.new(detail, fn {key, value} -> {sanitize_key(key), sanitize(value)} end)
  end

  defp sanitize(list) when is_list(list), do: Enum.map(list, &sanitize/1)

  defp sanitize(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&sanitize/1)
  end

  defp sanitize(other), do: other

  defp sanitize_key(key) when is_binary(key) or is_atom(key), do: key
  defp sanitize_key(key), do: inspect(key)

  @doc """
  Encodes any Jason-encodable term to a JSON string. Thin wrapper over
  `Jason.encode!/1`, kept here so callers don't need a direct `Jason`
  dependency reference just to finish the `encode/2` pipeline.
  """
  @spec encode_string(term()) :: String.t()
  def encode_string(term), do: Jason.encode!(term)
end
