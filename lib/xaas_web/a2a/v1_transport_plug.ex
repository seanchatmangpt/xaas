defmodule XaasWeb.A2A.V1TransportPlug do
  @moduledoc """
  W305 seam wrapper: mounts `AshA2A.Transport.Plug` (the owned transport,
  TQ-05 — it streams every reply) for the `/a2a/v1` surface while restoring
  the agent-card caching contract the vendored `AshA2A.Protocol.Plug` serves
  and this surface's court pins: `Cache-Control: public, max-age=300`
  (a2a v1.0 spec §8.6.1) plus the ETag/Last-Modified pair the transport
  already sets.

  Wrapper-only by design: the pinned dep (86214551) hardcodes the transport's
  card `Cache-Control: max-age=60`, and the SSE + card courts are both real
  wire assertions, so the wrapper is the irreducible hand-written residue.
  """

  def init(opts), do: AshA2A.Transport.Plug.init(opts)

  def call(conn, opts) do
    conn
    |> Plug.Conn.register_before_send(&restore_card_caching/1)
    |> AshA2A.Transport.Plug.call(opts)
  end

  # Only the GET agent card carries the §8.6.1 caching contract; SSE frames
  # (cache-control: no-cache) and JSON-RPC error envelopes are untouched.
  defp restore_card_caching(conn) do
    json_card? =
      conn.method == "GET" and
        match?(["application/json" <> _ | _], Plug.Conn.get_resp_header(conn, "content-type"))

    if json_card? do
      conn
      |> Plug.Conn.delete_resp_header("cache-control")
      |> Plug.Conn.put_resp_header("cache-control", "public, max-age=300")
    else
      conn
    end
  end
end
