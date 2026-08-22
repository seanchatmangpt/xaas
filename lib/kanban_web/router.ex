# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
defmodule KanbanWeb.Router do
  use KanbanWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {KanbanWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_internal_api_token do
    plug KanbanWeb.Plugs.RequireInternalApiToken
  end

  scope "/", KanbanWeb do
    pipe_through :browser
    get "/", PageController, :home
  end

  scope "/webhooks", KanbanWeb do
    pipe_through :api
    post "/stripe", StripeWebhookController, :receive
  end

  pipeline :internal_api do
    plug :accepts, ["json-api"]
  end

  # Specific internal routes must precede the AshJsonApi catch-all forward.
  # AshTypescript uses POST as its RPC transport, but every currently admitted
  # RPC action is read/observe-only and remains behind the same internal token
  # authority boundary as the other internal endpoints.
  scope "/internal-api", KanbanWeb do
    pipe_through [:api, :require_internal_api_token]

    get "/capability_liveness_regressions", CapabilityRegressionsController, :index
    get "/ocel_summary", OcelSummaryController, :index
    get "/prometheus/query", PrometheusQueryController, :query
    get "/health", HealthController, :index
    post "/rpc/run", AshTypescriptRpcController, :run
    post "/rpc/validate", AshTypescriptRpcController, :validate
  end

  scope "/internal-api" do
    pipe_through [:api, :require_internal_api_token]
    forward "/sparql", KanbanWeb.OntopProxyPlug
  end

  scope "/" do
    pipe_through [:internal_api, :require_internal_api_token]
    forward "/internal-api", KanbanWeb.InternalApiRouter
  end

  pipeline :resolve_org_actor do
    plug KanbanWeb.Plugs.ResolveOrgActor
  end

  scope "/" do
    pipe_through [:internal_api, :require_internal_api_token, :resolve_org_actor]
    forward "/api", KanbanWeb.ApiRouter
  end

  if Application.compile_env(:kanban, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: KanbanWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
      live "/dashboards/autofde-lab", KanbanWeb.AutofdeLab.StatusLive
    end

    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser
      ash_admin("/")
    end
  end
end
