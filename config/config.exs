# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
# in config/config.exs

# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :kanban,
  ecto_repos: [Kanban.Repo, Xaas.Repo],
  ash_domains: [
    Xaas.Accounts,
    Xaas.Billing,
    Xaas.Governance,
    Xaas.Ledger,
    Xaas.Operations,
    Xaas.Platform
  ],
  ash_authentication: [return_error_on_invalid_magic_link_token?: true],
  base_resources: [Xaas.Resource]

# ash-migration Phase 3: real Ash-ecosystem config ported verbatim from
# ~/dev-fresh/xaas/config/config.exs (the source the 89 resource files were
# actually written against) -- the resource files use short type codes
# (:money) and custom types (:capability_class, :interface) that only
# resolve via this real custom_types/known_types registration, confirmed by
# a real compile error (":money is not a valid type") before this was added.
# Real fix: opentelemetry_ash was added as a dep but never actually
# configured as Ash's tracer (confirmed via grep -- no `config :ash,
# :tracer` existed anywhere in this repo before this line). Without this,
# OpentelemetryAsh.start_span/2 is dead code -- Ash never calls it.
config :ash, :tracer, [OpentelemetryAsh]

config :ash_oban, pro?: false

config :kanban, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10],
  repo: Xaas.Repo,
  plugins: [{Oban.Plugins.Cron, []}]

config :ash_graphql, authorize_update_destroy_with_error?: true

config :ash_json_api,
  show_public_calculations_when_loaded?: false,
  authorize_update_destroy_with_error?: true

config :ash,
  allow_forbidden_field_for_relationships_by_default: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true,
  redact_sensitive_values_in_errors?: true,
  many_to_many_destroy_destination_on_match?: true,
  known_types: [AshPostgres.Timestamptz, AshPostgres.TimestamptzUsec, AshMoney.Types.Money],
  custom_types: [
    money: AshMoney.Types.Money,
    capability_class: Xaas.Governance.Types.CapabilityClass,
    interface: Xaas.Governance.Types.Interface,
    project_tier: Xaas.Governance.Types.ProjectTier,
    cmek_provider: Xaas.Governance.Types.CmekProvider
  ]

# Configures the endpoint
config :kanban, KanbanWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: KanbanWeb.ErrorHTML, json: KanbanWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Kanban.PubSub,
  live_view: [signing_salt: "27Dz+bCC"]

config :kanban, Kanban.PromEx,
  grafana: [
    host: "http://grafana:3000",
    upload_dashboards_on_start: true
  ]

config :kanban, Kanban.AwsRepo, adapter: Kanban.AwsRepo.FixtureAdapter

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  region: "eu-west-1",
  jason_codec: Jason,
  debug_requests: true

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :kanban, Kanban.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.2.4",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
