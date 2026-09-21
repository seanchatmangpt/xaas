# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
# in lib/xaas/application.ex

defmodule Xaas.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Real OCEL v2 + OpenTelemetry enrichment via Ash introspection: attach
    # before the supervision tree starts so every real Ash action from the
    # first request onward is captured. See
    # Xaas.Telemetry.OcelAshEmitter's moduledoc for the real telemetry
    # event names this hooks (confirmed via reading deps/ash's own
    # create/read/update/destroy.ex).
    Xaas.Telemetry.OcelAshEmitter.attach!()

    # Xaas.Sa2a.Bridge (lib/xaas/sa2a/bridge.ex) was never in this
    # supervision tree -- every sa2a-bridge-pack edge (validate/admit/
    # plan/execute/replay) was unreachable at runtime, calling
    # GenServer.call on a process that had never been started. Real,
    # honest, logged gate (not a silent no-op): `available?/0` checks
    # `System.find_executable("autofde")` at boot, exactly the same check
    # `init/1` performs -- an environment without autofde-lab installed
    # (e.g. a bare CI runner for this repo) must not fail application
    # boot over a missing optional binary, but the absence is logged, not
    # swallowed.
    sa2a_bridge_children =
      if Xaas.Sa2a.Bridge.available?() do
        [Xaas.Sa2a.Bridge]
      else
        Logger.warning(
          "Xaas.Sa2a.Bridge not started: \"autofde\" executable not found on PATH. " <>
            "sa2a-bridge-pack edges (validate/admit/plan/execute/replay) are unavailable " <>
            "until autofde-lab (https://github.com/seanchatmangpt/autofde-lab) is installed " <>
            "and its \"autofde\" console script is on PATH."
        )

        []
      end

    children =
      [
        # Start the Endpoint (http/https)
        XaasWeb.Endpoint,
        # Start PromEx
        Xaas.PromEx,
        # Real fix (confirmed via a real 2-pod kind cluster test this session):
        # "tasks.web" is a leftover Fly.io DNS name from the book's original
        # deployment target, meaningless in k8s -- both pods logged
        # "Cannot get connection id for node" trying to resolve it, and
        # Node.list() was empty on both. DNS_CLUSTER_QUERY is set via the
        # ConfigMap to the real headless Service (k8s/headless-service.yaml)
        # so DNSCluster gets one A record per pod, not a single ClusterIP VIP.
        {DNSCluster, query: System.get_env("DNS_CLUSTER_QUERY") || "tasks.web"},
        # Start the Telemetry supervisor
        XaasWeb.Telemetry,
        # Start the Ecto repository
        Xaas.LegacyRepo,
        # ash-migration Phase 3: real, separate AshPostgres.Repo for the 89
        # ported Xaas.* Ash.Resource modules -- additive, Xaas.LegacyRepo above is
        # untouched.
        Xaas.Repo,
        # Real finding, ULTRACODE-50 milestone (2026-09-14): Oban itself was
        # never in this supervision tree -- `config :xaas, Oban` (config.exs)
        # existed and 4 AshOban resources (Xaas.Library.HoldRequest,
        # Xaas.Operations.CapabilityLivenessReceipt,
        # Xaas.Platform.WebhookDelivery, Xaas.Ultracode.Run) all declare
        # real `scheduled_actions`/`triggers`, but with no supervised Oban
        # process, NONE of their cron jobs could ever fire in any
        # environment -- not a missing config value, a missing child.
        #
        # SECOND real finding, same milestone, caught by directly observing
        # a live node for 3 real wall-clock minutes: adding the child alone
        # was still not enough. `config.exs`'s `plugins: [{Oban.Plugins.
        # Cron, []}]` passes an EMPTY crontab -- Oban's Cron plugin doesn't
        # know about ANY AshOban resource's `scheduled_actions`/`triggers`
        # unless the base config is routed through `AshOban.config/2`
        # first, which reads every listed domain's AshOban DSL and merges
        # each resource's schedule into the plugin's actual crontab. Per
        # ash_oban's own getting-started doc: "even without a static config
        # change to plugins, use `AshOban.config(domains, base)` -- not raw
        # `Application.fetch_env!/2` -- as what's passed to `{Oban, ...}`."
        # Confirmed via a real running node + real Postgres queries: zero
        # `oban_jobs` rows for ANY Ultracode worker ever appeared across 9
        # real 20s polls (3 wall-clock minutes) before this fix; this is
        # the code that was missing to make that happen.
        {Oban,
         AshOban.config(
           Application.fetch_env!(:xaas, :ash_domains),
           Application.fetch_env!(:xaas, Oban)
         )},
        # AshCloak's backing Cloak.Vault -- must start before anything that
        # might read/write an encrypted attribute (Xaas.Accounts.Token's
        # encrypted_extra_data, Xaas.Platform.Webhook's encrypted secret), so
        # right after the repos it depends on and before Endpoint-adjacent
        # request-serving children. Real, previously-missing supervision --
        # tests used to work around this with a per-test
        # start_supervised!(Xaas.Vault); now the app boots it for real.
        Xaas.Vault,
        # Rate-limiter backend for AshRateLimiter (Xaas.Billing.ApprovalPricingOverride
        # :create action) -- ETS-backed, in-process.
        {Xaas.Hammer, clean_period: :timer.minutes(1)},
        # Start the PubSub system
        {Phoenix.PubSub, name: Xaas.PubSub},
        # Start Finch
        {Finch, name: Xaas.Finch},
        # Real A2A (Agent-to-Agent) agent simulating a Next Read reader
        # persona -- see XaasWeb.A2A.NextReadUserAgent's moduledoc. Started
        # as a supervised GenServer per `use A2A.Agent`'s generated
        # `start_link/1`; served over HTTP via the `/a2a` router scope.
        XaasWeb.A2A.NextReadUserAgent
        # Start a worker by calling: Xaas.Worker.start_link(arg)
        # {Xaas.Worker, arg}
      ] ++ sa2a_bridge_children

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Xaas.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    XaasWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
