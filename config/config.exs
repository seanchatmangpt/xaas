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
    Xaas.Ocel,
    Xaas.Operations,
    Xaas.Platform,
    Xaas.Ultracode
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

# ULTRACODE-50 milestone (2026-09-14): real finding — `AshOban.config/2`
# (wired into lib/xaas/application.ex's `{Oban, ...}` child, replacing a
# plain `Application.fetch_env!/2` that silently left the Cron plugin's
# crontab empty for every AshOban resource in this repo) refuses to boot
# unless every real trigger/scheduled_action's queue is explicitly listed
# here -- `queues: [default: 10]` alone only covered
# `Xaas.Ultracode.Run`'s `:tick` (explicitly pinned to `:default`, see
# that module's moduledoc). The other 3 pre-existing AshOban
# triggers/schedules never had an explicit `queue ...` override in their
# own DSL, so they use AshOban's default queue-naming convention
# (`<resource_short_name>_<schedule/trigger_name>`) -- confirmed via the
# real `RuntimeError` `AshOban.require_queues!/4` raised on boot, one at a
# time, until all three were named correctly.
config :xaas, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [
    default: 10,
    # One shared integration/promote wave at a time; construction concurrency
    # lives inside Xaas.Ultracode.Autonomic. `Xaas.Ultracode.Run`'s
    # `:autonomic_wave` and `:semantic_wave` schedules (every 30 minutes)
    # share this queue: exactly one slot so concurrent waves can never
    # overlap -- a wave's promote step is the loop's one shared-state operation.
    ultracode_wave: 1,
    hold_request_expire_stale_holds: 1,
    capability_liveness_receipt_check_regressions: 1,
    webhook_delivery_retry_failed_deliveries: 1,
    # `Xaas.Ultracode.Run`'s `:engine_cycle` schedule (every 5 minutes) --
    # the continuous engine between waves: same single-slot serialization
    # argument as `ultracode_wave` (slot-filling work must never overlap
    # itself, or capacity accounting races).
    ultracode_engine: 1
  ],
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

# Fabric-executed definition of done (`Xaas.Ultracode.Verifier`). Fail closed:
# no suites are registered by default, and a suite only ever runs in a worktree
# under `:ultracode_worktree_root`. Environments that use it register named
# suites (argv lists, never shell strings) in their own config file.
config :xaas, :ultracode_verifier_suites, %{}
config :xaas, :ultracode_worktree_root, nil
config :xaas, :ultracode_ticket_dir, nil
# Opt-in module value (an atom, e.g. Xaas.Ultracode.TargetSuites) whose devs/0
# declares extra fabric verifier suites for non-APS targets; Xaas.Ultracode.
# Verifier resolves it at runtime, never at config-evaluation time. nil = no
# extra suites.
config :xaas, :ultracode_target_suites, nil
config :xaas, :ultracode_repos, %{}

# The engine's per-provider worker-slot bound (`Xaas.Ultracode.Lease.
# pool_capacity/1`, enforced race-free inside `claim_next/3`): 5 live
# leases per provider -- the operator-ordered standing wave size, now a
# real fence on EVERY claim path (MCP workers included), not just the
# wave's in-process semaphore. Integer = one bound for all providers; a
# map gives per-provider bounds (`%{"zcode" => 5, default: 3}`); nil =
# unbounded (the test-env choice, so `LeaseConcurrencyStressTest`'s
# 25-way claim storm keeps its exact semantics). The default worker seam
# for `Xaas.Ultracode.Engine.fill/1` stays unset (observe-only engine);
# environments that want the engine actually dispatching configure
# `config :xaas, :ultracode_engine_worker, {Mod, :fun}`.
config :xaas, :ultracode_pool_capacity, 5

# The wave loop's judge seam (`Xaas.Ultracode.Autonomic.judge_receipt/1`).
# True (default): a receipt sealed `partial_alive` by an honest worker is
# accepted WITHOUT re-dispatch when the fabric's own court passed the exact
# head (`fabric_verifier.status == "pass"` AND `head_verified == true`) --
# the court, never the worker's self-assessment, is the promotion authority.
# `false` restores the strict alive-only predicate (pre-2026-09-19). The
# court's authority is never weakened: a fail/timeout/error verdict, a
# missing verdict, or an unverified head still repairs in both modes.
config :xaas, :ultracode_judge_accept_court_verified_partial, true

import_config "#{config_env()}.exs"
