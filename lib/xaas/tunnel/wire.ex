defmodule Xaas.Tunnel.Wire do
  @moduledoc """
  Authority-free wire admission for the bounded XaaS fabric.

  This module does not own transport or execution. It validates the envelope
  carried by HTTP/WSS adapters and projects only the three admitted fabric
  operations. Unknown operations, generic MCP, and actuation refuse before a
  downstream handler is invoked.
  """

  @version 1
  @kind "http"
  @allowed %{
    "fabric.probe" => :probe,
    "run.submit" => :submit,
    "epoch.receipts" => :receipts
  }

  @type admitted :: {:probe | :submit | :receipts, map()}
  @type refusal ::
          {:refused, :wire_version}
          | {:refused, :wire_kind}
          | {:refused, :operation}
          | {:refused, :authority_ceiling}
          | {:refused, :malformed}

  @spec admit(term()) :: {:ok, admitted()} | refusal()
  def admit(%{"v" => @version, "kind" => @kind, "operation" => operation} = envelope)
      when is_binary(operation) do
    cond do
      operation in ["actuate", "do", "command.execute"] ->
        {:refused, :authority_ceiling}

      Map.has_key?(@allowed, operation) ->
        payload = Map.get(envelope, "payload", %{})

        if is_map(payload),
          do: {:ok, {Map.fetch!(@allowed, operation), payload}},
          else: {:refused, :malformed}

      true ->
        {:refused, :operation}
    end
  end

  def admit(%{"v" => version}) when version != @version, do: {:refused, :wire_version}
  def admit(%{"v" => @version, "kind" => kind}) when kind != @kind, do: {:refused, :wire_kind}
  def admit(_), do: {:refused, :malformed}

  @doc """
  Dispatch an admitted envelope through a caller-owned function.

  The callback is invoked exactly once only after admission. Refusals are
  returned directly, preserving the zero-unreceipted-actuation boundary.
  """
  @spec dispatch(term(), (atom(), map() -> term())) :: term()
  def dispatch(envelope, fun) when is_function(fun, 2) do
    case admit(envelope) do
      {:ok, {operation, payload}} -> fun.(operation, payload)
      refusal -> refusal
    end
  end

  @spec response(non_neg_integer(), map()) :: map()
  def response(status, body) when is_integer(status) and status >= 100 and status <= 599 and is_map(body) do
    %{"v" => @version, "kind" => "http_response", "status" => status, "body" => body}
  end
end
