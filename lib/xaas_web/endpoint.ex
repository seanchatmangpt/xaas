# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
# in lib/xaas_web/endpoint.ex

defmodule XaasWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :xaas

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_xaas_key",
    signing_salt: "8PSILiaE",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  # Serve generated ash_surface artifacts (JS client, contract, live view,
  # ARIA) at /ash_surface from priv/ash_surface. Regenerate any time with
  # `mix xaas.ash_surface` (alias: `mix ash_surface`).
  plug(Plug.Static,
    at: "/ash_surface",
    from: {:xaas, "priv/ash_surface"},
    gzip: false
  )

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug(Plug.Static,
    at: "/",
    from: :xaas,
    gzip: false,
    only: XaasWeb.static_paths()
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(AshAi.Mcp.Dev,
      # For many tools, you will need to set the `protocol_version_statement` to the older version.
      protocol_version_statement: "2024-11-05",
      otp_app: :xaas,
      path: "/ash_ai/mcp"
    )

    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
    plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :xaas)
  end

  plug(Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"
  )

  plug(PromEx.Plug, prom_ex_module: Xaas.PromEx)
  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  # W150 (W113 finding 2): JSON-RPC parse errors on /a2a must be -32700 per
  # JSON-RPC 2.0. Plug.Parsers would raise ParseError (bare 400) on malformed
  # application/json before AshA2A.Protocol.Plug's raw-body branch can
  # classify it. See XaasWeb.Plugs.A2AParseFloor's moduledoc. Must run
  # BEFORE Plug.Parsers.
  plug(XaasWeb.Plugs.A2AParseFloor)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    length: 8_000_000,
    json_decoder: Phoenix.json_library(),
    body_reader: {XaasWeb.Plugs.StripeRawBodyReader, :read_body, []}
  )

  # W521 (EU AI Act wave): Art. 5 structural admission over /a2a JSON-RPC
  # params before agent dispatch. Runs after Plug.Parsers so /a2a POST
  # body_params are already decoded (the A2AParseFloor fetched them); only
  # refuses, with the surface's JSON-RPC error envelope. See
  # XaasWeb.Plugs.EuAiActAdmissionPlug's moduledoc.
  # W533 (EU AI Act wave): Art. 50(2) machine-detectable synthetic-content
  # marking. Every POST response from the AI surfaces (/a2a, /mcp) is
  # marked after the handler (register_before_send): `x-ai-generated: true`
  # header plus `"ai_generated": true` in JSON object bodies. Registered
  # BEFORE the W521 admission gate so refusal envelopes that halt in that
  # gate are marked too (Plug.Builder skips remaining plugs once halted;
  # before_send callbacks registered here still run on the halted send).
  # Zero-config, unconditional. See SyntheticMarkingPlug's moduledoc.
  plug(XaasWeb.Plugs.SyntheticMarkingPlug)
  plug(XaasWeb.Plugs.EuAiActAdmissionPlug)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(XaasWeb.Router)
end
