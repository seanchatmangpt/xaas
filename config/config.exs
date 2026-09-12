# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
import Config

config :xaas,
  ecto_repos: [Xaas.LegacyRepo, Xaas.Repo],
  ash_domains: [
    Xaas.Library,
    Xaas.Accounts,
    Xaas.Billing,
    Xaas.Coupling,
    Xaas.Generation,
    Xaas.Governance,
    Xaas.Ledger,
    Xaas.Marketplace,
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
# Xaas.Telemetry.OcelAshEmitter is registered here too (not just attached
# to :telemetry): it needs the real Ash.Tracer.set_handled_error/set_error
# callbacks (fired synchronously, in-process, on real action errors) to
# distinguish OCEL outcome "ok" from "error" -- see that module's moduledoc.
config :ash, :tracer, [OpentelemetryAsh, Xaas.Telemetry.OcelAshEmitter]

config :ash_oban, pro?: false

# Config surface for the ex4pm ontology staleness check
# (Xaas.Ontology.Ex4pmStaleness / mix xaas.telemetry.check_ontology_staleness).
# Single-sources repo path, pin, and both file paths so the mix task and the
# ExUnit test can never drift from each other. See
# docs/claude/diataxis/reference/ex4pm-ontology-pin.md for how to update
# `pinned_sha` safely.
config :xaas, :ex4pm_ontology_check,
  repo_path: System.get_env("EX4PM_REPO_PATH", Path.expand("~/ex4pm")),
  pinned_sha: "ade25ed12e93f89e7a2e1490698f99ae4947d702",
  upstream_path: "lib/ex4pm/ocel.ex",
  vendored_path: "priv/vendor/ex4pm/ocel.ex"

config :xaas, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10],
  repo: Xaas.Repo,
  plugins: [{Oban.Plugins.Cron, []}]

config :ash_graphql, authorize_update_destroy_with_error?: true

config :ash_json_api,
  show_public_calculations_when_loaded?: false,
  authorize_update_destroy_with_error?: true

# v26.8.21: generated TypeScript and the Phoenix router share the same
# authenticated endpoint identity. The RPC controller is mounted behind
# RequireInternalApiToken; generated clients may not silently target an
# unmounted public path.
config :ash_typescript,
  otp_app: :xaas,
  output_file: "assets/js/ash_rpc.ts",
  run_endpoint: "/internal-api/rpc/run",
  validate_endpoint: "/internal-api/rpc/validate",
  output_field_formatter: :camel_case,
  input_field_formatter: :camel_case

config :ash,
  default_string_length_count: :codepoints,
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
    cmek_provider: Xaas.Governance.Types.CmekProvider,
    pentest_finding_resolution: Xaas.Governance.Types.PentestFindingResolution,
    environment: Xaas.Governance.Types.Environment,
    change_of_control_event_type: Xaas.Governance.Types.ChangeOfControlEventType,
    export_subscription_cadence: Xaas.Governance.Types.ExportSubscriptionCadence,
    export_subscription_scope: Xaas.Governance.Types.ExportSubscriptionScope,
    le_request_type: Xaas.Governance.Types.LeRequestType,
    le_response_status: Xaas.Governance.Types.LeResponseStatus,
    insurance_coverage_type: Xaas.Governance.Types.InsuranceCoverageType,
    override_decision: Xaas.Governance.Types.OverrideDecision,
    subprocessor_category: Xaas.Governance.Types.SubprocessorCategory,
    subprocessor_change_action: Xaas.Governance.Types.SubprocessorChangeAction,
    org_role: Xaas.Governance.Types.OrgRole,
    deployment_quarantine_reason: Xaas.Governance.Types.DeploymentQuarantineReason,
    incident_severity: Xaas.Operations.Types.IncidentSeverity,
    incident_status: Xaas.Operations.Types.IncidentStatus,
    incident_postmortem_status: Xaas.Operations.Types.IncidentPostmortemStatus,
    pentest_finding_severity: Xaas.Governance.Types.PentestFindingSeverity,
    pentest_finding_status: Xaas.Governance.Types.PentestFindingStatus
  ]

# Configures the endpoint
config :xaas, XaasWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: XaasWeb.ErrorHTML, json: XaasWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Xaas.PubSub,
  live_view: [signing_salt: "27Dz+bCC"]

config :xaas, Xaas.PromEx,
  grafana: [
    host: "http://grafana:3000",
    upload_dashboards_on_start: true
  ]

config :xaas, Xaas.AwsRepo, adapter: Xaas.AwsRepo.FixtureAdapter

# Next Read ILS integration: FixtureAdapter remains the configured default
# since no real ILS vendor account/endpoint exists in this environment.
# Xaas.Library.ILSRepo.SIP2Adapter is available but not defaulted -- see
# docs/case-studies/next-read/ILS-AND-EXPLANATION-SUBSTITUTION.md.
config :xaas, Xaas.Library.ILSRepo, adapter: Xaas.Library.ILSRepo.FixtureAdapter

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
config :xaas, Xaas.Mailer, adapter: Swoosh.Adapters.Local

config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

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

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
