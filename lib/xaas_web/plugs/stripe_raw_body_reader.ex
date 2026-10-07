defmodule XaasWeb.Plugs.StripeRawBodyReader do
  @moduledoc """
  Real custom `:body_reader` for `Plug.Parsers` (wired in
  `XaasWeb.Endpoint`) -- Stripe's real signature verification
  (`Stripe.Webhook.construct_event/3`) requires the exact raw request
  body bytes, but `Plug.Parsers` normally consumes and discards the raw
  body while decoding it to a parsed map, leaving nothing for the
  controller to verify against by the time it runs.

  This reader delegates to the real default `Plug.Conn.read_body/2` for
  every request (so JSON parsing continues to work exactly as before for
  every other route), but for requests under `/webhooks/stripe`
  additionally stashes the real raw bytes into `conn.assigns[:raw_body]`
  before they're handed off to the JSON decoder, so
  `XaasWeb.StripeWebhookController` can verify the real signature
  against the real bytes Stripe actually sent.

  W794: the same cache now also covers `/internal-api/sparql` -- the
  `XaasWeb.OntopProxyPlug` reverse proxy is a router route that runs AFTER
  this endpoint `Plug.Parsers` entry, so for `urlencoded`/`multipart`/`json`
  POSTs (e.g. SPARQL 1.1 Protocol form POSTs) the raw body was consumed
  before the proxy ran and the proxy forwarded an empty body upstream
  (W776 gap `UNSUPPORTED(raw_body_preservation_after_parsers)`). Caching
  the exact raw bytes in `conn.assigns[:raw_body]` here lets the proxy
  forward them byte-exact.
  """

  # Path prefixes (as `conn.path_info` lists) whose exact raw request body
  # is cached into `conn.assigns[:raw_body]`.
  @raw_body_paths [["webhooks", "stripe"], ["internal-api", "sparql"]]

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      # Over-limit: return {:more, ...} so Plug.Parsers raises its typed
      # RequestTooLargeError (413) instead of crashing with MatchError (500).
      {:more, _body, _conn} = more -> more
      {:ok, body, conn} -> {:ok, body, assign_raw_body(conn, body)}
    end
  end

  defp assign_raw_body(conn, body) do
    if conn.path_info in @raw_body_paths do
      existing = Map.get(conn.assigns, :raw_body, "")
      Plug.Conn.assign(conn, :raw_body, existing <> body)
    else
      conn
    end
  end
end
