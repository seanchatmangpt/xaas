defmodule XaasWeb.Plugs.A2AParseFloor do
  @moduledoc """
  W150 (W113 finding 2): malformed JSON on the `/a2a` JSON-RPC surface must
  answer the JSON-RPC 2.0 parse error -32700, not -32600 and not a bare 400
  from Plug.Parsers.ParseError.

  Root cause: XaasWeb.Endpoint runs Plug.Parsers with :json before the
  router, so an application/json body is decoded endpoint-wide before
  AshA2A.Protocol.Plug's own read_json_body/1 can classify a decode failure
  as -32700. The pinned dep (86214551) classifies correctly; its raw-body
  branch was simply unreachable for application/json traffic.

  Fix shape: for POSTs under /a2a this plug performs the JSON decode itself
  and either (a) hands the decoded map downstream as an already-fetched
  body_params -- Plug.Parsers and AshA2A.Protocol.Plug both honor that -- or
  (b) answers the JSON-RPC -32700 envelope directly, matching exactly the
  AshA2A.Protocol.Plug dispatch_json_rpc parse_error shape (HTTP 200, id
  null, code -32700, message "Invalid JSON payload").

  Text/event-stream SSE requests, GETs (agent card), and every non-/a2a path
  pass through untouched, so Plug.Parsers/StripeRawBodyReader behavior is
  unchanged elsewhere.
  """
  @behaviour Plug

  @max_body 8_000_000

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{method: "POST", path_info: ["a2a" | _]} = conn, _opts) do
    case Plug.Conn.read_body(conn, length: @max_body) do
      {:ok, raw, conn} ->
        case Jason.decode(raw) do
          {:ok, decoded} when is_map(decoded) ->
            mark_fetched(conn, decoded)

          {:ok, _non_map} ->
            # A valid-JSON non-object body decodes fine but is not a valid
            # JSON-RPC request; let the pinned dep classify it (-32600).
            mark_fetched(conn, %{})

          {:error, %Jason.DecodeError{}} ->
            parse_error(conn)

          {:error, _other} ->
            parse_error(conn)
        end

      {:more, _partial, conn} ->
        parse_error(conn, "Body too large")

      {:error, reason} ->
        parse_error(conn, inspect(reason))
    end
  end

  def call(conn, _opts), do: conn

  # Both Plug.Parsers and AshA2A.Protocol.Plug's read_json_body/1 treat an
  # already-fetched body_params as authoritative and skip their own parsing.
  defp mark_fetched(conn, decoded) do
    %{conn | body_params: decoded}
  end

  # Mirrors AshA2A.Protocol.Plug's send_json + Error.parse_error shape:
  # HTTP 200, id null, code -32700, message "Invalid JSON payload".
  defp parse_error(conn, detail \\ nil) do
    message =
      if is_binary(detail) and detail != "" do
        "Invalid JSON payload: " <> detail
      else
        "Invalid JSON payload"
      end

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(
      200,
      Jason.encode!(%{
        jsonrpc: "2.0",
        id: nil,
        error: %{code: -32_700, message: message}
      })
    )
    |> Plug.Conn.halt()
  end
end
