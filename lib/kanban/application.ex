# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
# in lib/kanban/application.ex

defmodule Kanban.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Real OCEL v2 + OpenTelemetry enrichment via Ash introspection: attach
    # before the supervision tree starts so every real Ash action from the
    # first request onward is captured. See
    # Xaas.Telemetry.OcelAshEmitter's moduledoc for the real telemetry
    # event names this hooks (confirmed via reading deps/ash's own
    # create/read/update/destroy.ex).
    Xaas.Telemetry.OcelAshEmitter.attach!()

    children = [
      # Start the Endpoint (http/https)
      KanbanWeb.Endpoint,
      # Start PromEx
      Kanban.PromEx,
      # Real fix (confirmed via a real 2-pod kind cluster test this session):
      # "tasks.web" is a leftover Fly.io DNS name from the book's original
      # deployment target, meaningless in k8s -- both pods logged
      # "Cannot get connection id for node" trying to resolve it, and
      # Node.list() was empty on both. DNS_CLUSTER_QUERY is set via the
      # ConfigMap to the real headless Service (k8s/headless-service.yaml)
      # so DNSCluster gets one A record per pod, not a single ClusterIP VIP.
      {DNSCluster, query: System.get_env("DNS_CLUSTER_QUERY") || "tasks.web"},
      # Start the Telemetry supervisor
      KanbanWeb.Telemetry,
      # Start the Ecto repository
      Kanban.Repo,
      # ash-migration Phase 3: real, separate AshPostgres.Repo for the 89
      # ported Xaas.* Ash.Resource modules -- additive, Kanban.Repo above is
      # untouched.
      Xaas.Repo,
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
      {Phoenix.PubSub, name: Kanban.PubSub},
      # Start Finch
      {Finch, name: Kanban.Finch}
      # Start a worker by calling: Kanban.Worker.start_link(arg)
      # {Kanban.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Kanban.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KanbanWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
