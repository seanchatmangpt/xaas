# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
defmodule XaasWeb.Router do
  use XaasWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {XaasWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Real fix (adversarial review finding): neither /internal-api nor /api
  # had any auth plug at all -- both real 200'd for any anonymous client.
  pipeline :require_internal_api_token do
    plug(XaasWeb.Plugs.RequireInternalApiToken)
  end

  # Real, minimal fix for the closed ERRC item auditing `/mcp` caller
  # identity on every tool invocation -- see `XaasWeb.Plugs.
  # AuditMcpToolCall`'s moduledoc and the `/mcp` scope below for the
  # full rationale. Deliberately not applied to `/api` or
  # `/internal-api` -- this item's real scope is the `/mcp` gap
  # specifically.
  pipeline :audit_mcp_tool_call do
    plug(XaasWeb.Plugs.AuditMcpToolCall)
  end

  scope "/", XaasWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    live("/next-read", NextRead.ReaderLive)
  end

  # Real public external Stripe webhook receiver -- deliberately NOT
  # behind :require_internal_api_token (Stripe is the caller, not us; it
  # cannot supply our internal bearer token). Real authenticity check is
  # Stripe-signature verification inside the controller itself. See
  # XaasWeb.StripeWebhookController's moduledoc.
  scope "/webhooks", XaasWeb do
    pipe_through(:api)

    post("/stripe", StripeWebhookController, :receive)
  end

  pipeline :internal_api do
    plug(:accepts, ["json-api"])
  end

  # Real fix: this specific route must be registered BEFORE the catch-all
  # `forward "/internal-api"` below -- a Phoenix `forward` matches every
  # sub-path under its prefix, so declared after this one it would shadow
  # it (confirmed via a real 404 from AshJsonApi.Router's own
  # "no_route_found" before this reorder).
  scope "/internal-api", XaasWeb do
    pipe_through([:api, :require_internal_api_token])

    get("/capability_liveness_regressions", CapabilityRegressionsController, :index)
    get("/ocel_summary", OcelSummaryController, :index)
    get("/prometheus/query", PrometheusQueryController, :query)
    get("/health", HealthController, :index)
  end

  # Production MCP server: read-only Library tools (see Xaas.Library's
  # `tools do` block). Gated behind the same `:require_internal_api_token`
  # Bearer check as `/api` -- an MCP caller is not a separate trust tier.
  #
  # CORRECTED (real finding from this session's adversarial ERRC review,
  # confirmed by reading `resolve_org_actor.ex` itself): `:resolve_org_actor`
  # is listed in this pipeline but does NOT actually resolve anything for
  # `/mcp` traffic. Its `tenant_scoped?/1` only matches when
  # `conn.path_info` is `["api", <segment in the 14-entry allowlist> | _]`
  # (`resolve_org_actor.ex:150-232`) -- for `/mcp` requests `path_info` is
  # `["mcp", ...]`, which matches neither branch, so the plug's `cond`
  # falls through to `true -> conn` (unchanged, no actor/tenant set). The
  # real gate on what an MCP caller can read is `Book`/`Curation`'s own
  # `policy action_type(:read) do authorize_if always() end`
  # (`book.ex:103-104`, `curation.ex:63-65`) -- i.e. any bearer-token
  # holder can read all books/curations regardless of org, full stop. Left
  # in the pipeline (harmless no-op today) rather than removed, since a
  # future tenant-scoped Library resource would want it; do not read its
  # presence here as proof tenant scoping is active for these two
  # resources -- it is not.
  # Real, smallest-scope fix (this session, per cycle 0138's explicit
  # rejection of a full tenant-filter redesign as scope creep): the read
  # policy itself stays `authorize_if always()` -- untouched. Instead,
  # `:audit_mcp_tool_call` (`XaasWeb.Plugs.AuditMcpToolCall`) writes one
  # real `Xaas.Operations.AuditLogEntry` row per `/mcp` HTTP request
  # before it is forwarded to `AshAi.Mcp.Router`, so unscoped reads are
  # at least observable (which bearer token, which path, when) rather
  # than invisible. See that plug's moduledoc for the full rationale.
  # Tool list, protocol version, and otp_app are now generated
  # (priv/ggen_igniter/mcp_a2a/xaas-surface.ttl -> XaasWeb.McpScope --
  # see that module's own moduledoc to regenerate). The pipeline itself
  # stays hand-written here since routers commonly have hand-authored
  # pipelines this pack deliberately does not overwrite. `mount/0` is a
  # macro (its body expands `forward/3` at the call site inside `scope`),
  # so it must be `import`ed and called bare -- `require` +
  # fully-qualified `XaasWeb.McpScope.mount()` does not work for macros.
  require XaasWeb.McpScope
  import XaasWeb.McpScope, only: [mount: 0]

  scope "/mcp" do
    pipe_through([
      :api,
      :require_internal_api_token,
      :resolve_org_actor,
      :audit_mcp_tool_call
    ])

    mount()
  end

  # Real A2A (Agent-to-Agent) server: lets an MCP-speaking LLM drive
  # multiple simulated Next Read user personas concurrently (see
  # XaasWeb.A2A.NextReadUserAgent's moduledoc). Same auth philosophy as
  # `/mcp` above -- gated behind the real `/api` pipeline, not a separate
  # silo, though see that agent's moduledoc for the actor-resolution
  # mechanism actually used inside message handling (an explicit
  # `as:<user_id>` command prefix, not `X-Org-Id`/`ResolveOrgActor`, since
  # A2A messages are plain text, not JSON:API requests `ResolveOrgActor`
  # inspects by path).
  scope "/a2a" do
    pipe_through([:api, :require_internal_api_token])

    forward("/", A2A.Plug,
      agent: XaasWeb.A2A.NextReadUserAgent,
      base_url: System.get_env("A2A_BASE_URL") || "http://localhost:4000/a2a"
    )
  end

  # GGen workbench is ordinary authenticated JSON, not JSON:API. Registered
  # before the /api forward catch-all so the latter cannot shadow it. The
  # surface is CONSTRUCT-only: it forwards a bounded file bundle and argv
  # vector to the private Fly worker; it does not grant shell or cloud
  # actuation authority.
  scope "/api/workbench", XaasWeb do
    pipe_through([:api, :require_internal_api_token])

    get("/ggen/health", GgenWorkbenchController, :health)
    post("/ggen", GgenWorkbenchController, :run)
  end

  # Real reverse-proxy for the real Ontop SPARQL endpoint (see
  # XaasWeb.OntopProxyPlug's moduledoc and
  # docs/claude/diataxis/explanation/r2rml-ontop-prototype.md). Registered
  # BEFORE the catch-all `forward "/internal-api"` below for the same real
  # reason as `/capability_liveness_regressions` etc. above -- `forward`
  # matches every sub-path under its prefix and would otherwise shadow
  # this route.
  scope "/internal-api" do
    pipe_through([:api, :require_internal_api_token])

    forward("/sparql", XaasWeb.OntopProxyPlug)
  end

  scope "/" do
    pipe_through([:internal_api, :require_internal_api_token])

    forward("/internal-api", XaasWeb.InternalApiRouter)
  end

  # Real per-org actor/tenant resolution (XaasWeb.Plugs.ResolveOrgActor),
  # scoped to /api only. The plug itself is path-aware and only enforces
  # X-Org-Id resolution for the 4 non-global-multitenancy governance
  # resources (ApprovalDrFailover/ApprovalLegalHoldRelease/
  # ApprovalDeploymentQuarantine/ApprovalBackupRetentionChange) -- every
  # other /api route passes through unaffected. See that plug's moduledoc
  # for the full, disclosed design decision.
  pipeline :resolve_org_actor do
    plug(XaasWeb.Plugs.ResolveOrgActor)
  end

  scope "/" do
    pipe_through([:internal_api, :require_internal_api_token, :resolve_org_actor])

    forward("/api", XaasWeb.ApiRouter)
  end

  # Other scopes may use custom stacks.
  # scope "/api", XaasWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:xaas, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: XaasWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
      live("/dashboards/autofde-lab", XaasWeb.AutofdeLab.StatusLive)
    end

    # ash-admin: real AshAdmin.Router mount, dev-only (guarded by the same
    # dev_routes flag as LiveDashboard above) -- production exposure would
    # need real auth, deliberately not added here per the same reasoning
    # as the LiveDashboard comment above.
    import AshAdmin.Router

    scope "/admin" do
      pipe_through(:browser)

      ash_admin("/")
    end
  end
end
