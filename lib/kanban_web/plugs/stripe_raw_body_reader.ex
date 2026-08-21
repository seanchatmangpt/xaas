defmodule KanbanWeb.Plugs.StripeRawBodyReader do
  @moduledoc """
  Real custom `:body_reader` for `Plug.Parsers` (wired in
  `KanbanWeb.Endpoint`) -- Stripe's real signature verification
  (`Stripe.Webhook.construct_event/3`) requires the exact raw request
  body bytes, but `Plug.Parsers` normally consumes and discards the raw
  body while decoding it to a parsed map, leaving nothing for the
  controller to verify against by the time it runs.

  This reader delegates to the real default `Plug.Conn.read_body/2` for
  every request (so JSON parsing continues to work exactly as before for
  every other route), but for requests under `/webhooks/stripe`
  additionally stashes the real raw bytes into `conn.assigns[:raw_body]`
  before they're handed off to the JSON decoder, so
  `KanbanWeb.StripeWebhookController` can verify the real signature
  against the real bytes Stripe actually sent.
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)

    conn =
      if conn.path_info == ["webhooks", "stripe"] do
        existing = Map.get(conn.assigns, :raw_body, "")
        Plug.Conn.assign(conn, :raw_body, existing <> body)
      else
        conn
      end

    {:ok, body, conn}
  end
end
