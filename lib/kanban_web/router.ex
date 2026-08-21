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

  # Real fix (adversarial review finding): neither /internal-api nor /api
  # had any auth plug at all -- both real 200'd for any anonymous client.
  pipeline :require_internal_api_token do
    plug KanbanWeb.Plugs.RequireInternalApiToken
  end

  scope "/", KanbanWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Real public external Stripe webhook receiver -- deliberately NOT
  # behind :require_internal_api_token (Stripe is the caller, not us; it
  # cannot supply our internal bearer token). Real authenticity check is
  # Stripe-signature verification inside the controller itself. See
  # KanbanWeb.StripeWebhookController's moduledoc.
  scope "/webhooks", KanbanWeb do
    pipe_through :api

    post "/stripe", StripeWebhookController, :receive
  end

  pipeline :internal_api do
    plug :accepts, ["json-api"]
  end

  # Real fix: this specific route must be registered BEFORE the catch-all
  # `forward "/internal-api"` below -- a Phoenix `forward` matches every
  # sub-path under its prefix, so declared after this one it would shadow
  # it (confirmed via a real 404 from AshJsonApi.Router's own
  # "no_route_found" before this reorder).
  scope "/internal-api", KanbanWeb do
    pipe_through [:api, :require_internal_api_token]

    get "/capability_liveness_regressions", CapabilityRegressionsController, :index
    get "/ocel_summary", OcelSummaryController, :index
    get "/prometheus/query", PrometheusQueryController, :query
  end

  scope "/" do
    pipe_through [:internal_api, :require_internal_api_token]

    forward "/internal-api", KanbanWeb.InternalApiRouter
  end

  # Real per-org actor/tenant resolution (KanbanWeb.Plugs.ResolveOrgActor),
  # scoped to /api only. The plug itself is path-aware and only enforces
  # X-Org-Id resolution for the 4 non-global-multitenancy governance
  # resources (ApprovalDrFailover/ApprovalLegalHoldRelease/
  # ApprovalDeploymentQuarantine/ApprovalBackupRetentionChange) -- every
  # other /api route passes through unaffected. See that plug's moduledoc
  # for the full, disclosed design decision.
  pipeline :resolve_org_actor do
    plug KanbanWeb.Plugs.ResolveOrgActor
  end

  scope "/" do
    pipe_through [:internal_api, :require_internal_api_token, :resolve_org_actor]

    forward "/api", KanbanWeb.ApiRouter
  end

  # Other scopes may use custom stacks.
  # scope "/api", KanbanWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:kanban, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: KanbanWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
      live "/dashboards/autofde-lab", KanbanWeb.AutofdeLab.StatusLive
    end

    # ash-admin: real AshAdmin.Router mount, dev-only (guarded by the same
    # dev_routes flag as LiveDashboard above) -- production exposure would
    # need real auth, deliberately not added here per the same reasoning
    # as the LiveDashboard comment above.
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin("/")
    end
  end
end
