defmodule Xaas.Sjira.RateLimit do
  @moduledoc """
  Deterministic retry-delay selection for Atlassian delivery.

  Server instructions win over local exponential backoff. Retry-After accepts
  integer seconds; X-RateLimit-Reset accepts a Unix epoch in seconds. Unknown
  or malformed headers fall back to capped exponential backoff.

  Jitter is deliberately supplied by the caller, not hidden here, so a swarm
  can preserve deterministic scheduling when desired.
  """

  @type headers :: map() | [{term(), term()}]

  @spec delay_ms(headers(), pos_integer(), keyword()) :: non_neg_integer()
  def delay_ms(headers, attempt, opts \\ []) when attempt >= 1 do
    now_ms = Keyword.get_lazy(opts, :now_ms, fn -> System.system_time(:millisecond) end)
    base_ms = Keyword.get(opts, :base_backoff_ms, 500)
    max_ms = Keyword.get(opts, :max_backoff_ms, 30_000)

    instructed =
      retry_after_ms(headers) ||
        reset_after_ms(headers, now_ms)

    instructed
    |> Kernel.||(exponential(base_ms, attempt))
    |> max(0)
    |> min(max_ms)
  end

  @spec retry_after_ms(headers()) :: non_neg_integer() | nil
  def retry_after_ms(headers) do
    case header(headers, "retry-after") do
      nil ->
        nil

      value ->
        case Integer.parse(String.trim(value)) do
          {seconds, ""} when seconds >= 0 -> seconds * 1_000
          _ -> nil
        end
    end
  end

  @spec reset_after_ms(headers(), integer()) :: non_neg_integer() | nil
  def reset_after_ms(headers, now_ms) do
    value =
      header(headers, "x-ratelimit-reset") ||
        header(headers, "x-rate-limit-reset")

    case value && Integer.parse(String.trim(value)) do
      {epoch_seconds, ""} when epoch_seconds >= 0 ->
        max(epoch_seconds * 1_000 - now_ms, 0)

      _ ->
        nil
    end
  end

  @spec header(headers(), String.t()) :: String.t() | nil
  def header(headers, wanted) do
    wanted = String.downcase(wanted)

    headers
    |> normalize()
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(key) == wanted, do: value
    end)
  end

  @spec normalize(headers()) :: [{String.t(), String.t()}]
  def normalize(%{} = headers) do
    Enum.map(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  def normalize(headers) when is_list(headers) do
    Enum.flat_map(headers, fn
      {key, value} -> [{to_string(key), to_string(value)}]
      _ -> []
    end)
  end

  def normalize(_), do: []

  defp exponential(base, attempt) do
    shift = max(attempt - 1, 0)
    base * Integer.pow(2, shift)
  end
end
