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
    Xaas.TemporalMemory,
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
#
# The wave loop's concurrency mode (2026-09-26, operator-ordered): the
# `:wave_loop` schedule fires every 5 minutes and up to
# `wave_loop_concurrency` loop workers may be in flight, fanned across
# INDEPENDENT steps only (a step held by a live lease is excluded from the
# next tick's selection). The number must stay <= `:ultracode_pool_capacity`
# below -- the pool bound is what actually fences live leases per provider.
# Measured agent turns average minutes (burn-in 2026-09-26: a mechanical
# step ~1-6 min), so a 5-minute cadence with 3 slots keeps the loop fed
# without pile-up; surplus fires record `busy` and exit 0.
# 1 for now: parallel steps sharing ONE work surface used to collide on the
# per-cwd lease state file (sha256(cwd), exit 65 lease_conflict; observed
# 2026-09-27 00:11-00:35 — the second worker lawfully waited out the
# first's lease). Per-epoch lease keys (XAAS_LEASE_ID, zcode-cli c2adb24 +
# dispatch env) remove the lease-file collision; the remaining boundary to
# raising this is git-contention on the SHARED work surface (two workers
# committing one repo race on index.lock) — per-step work surfaces first.
wave_loop_concurrency = 1

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
    ultracode_engine: 1,
    # `Xaas.Ultracode.Run`'s `:wave_loop` schedule (every 5 minutes) --
    # the fabric-native wave loop: the slot serializes tick EXECUTION
    # (`Xaas.Ultracode.WaveLoop.tick/1` against the loop STATE file), not
    # worker count -- one tick now dispatches a work-conserving batch of
    # ready steps in parallel. A tick's dispatch may legitimately run most
    # of an hour, so the slot is what keeps two ticks from overlapping; a
    # surplus fire waits here and still records `busy`.
    ultracode_wave_loop: wave_loop_concurrency
  ],
  repo: Xaas.Repo,
  plugins: [
    # Daily self-digest (Xaas.Ultracode.SelfDigestWorker, queue
    # :ultracode_wave): off the :00 minute so it never lands on the */30
    # wave boundary. AshOban.config/2 prepends its own schedules to this list.
    {Oban.Plugins.Cron, crontab: [{"17 6 * * *", Xaas.Ultracode.SelfDigestWorker}]},
    # P0.1 dispatch watchdog (fleet-sweep ticket, 2026-09-27): a BEAM death
    # mid-tick (e.g. the 04:52Z server relaunch while oban job 20628 was
    # executing) leaves the row `executing` FOREVER — no worker spawns, the
    # concurrency-1 queue serializes on it, and recovery needed manual SQL.
    # Lifeline orphans such jobs back to `available` once they exceed the
    # maximum legitimate tick (dispatch timeout 3300s + margin). Oban's
    # uniqueness then treats the orphan as incomplete, so the same job is
    # rescued, not duplicated.
    {Oban.Lifeline, rescue_after: {75, :minutes}}
  ]

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
  input_field_formatter: :camel_case,
  # ash_typescript 0.18: the manifest module is mandatory (AshTypescript.manifest_module/0)
  manifest: Xaas.AshTypescriptManifest

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
    pentest_finding_status: Xaas.Governance.Types.PentestFindingStatus,
    frontier_outcome: Xaas.Ultracode.CapitalCensus.Types.FrontierOutcome,
    gap_status: Xaas.Ultracode.CapitalCensus.Types.GapStatus,
    primitive_target: Xaas.Ultracode.CapitalCensus.Types.PrimitiveTarget,
    recurrence_class: Xaas.Ultracode.CapitalCensus.Types.RecurrenceClass,
    resolution_outcome: Xaas.Ultracode.CapitalCensus.Types.ResolutionOutcome,
    work_order_status: Xaas.Ultracode.CapitalCensus.Types.WorkOrderStatus
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

# Same fail-closed law for the sense stage (`Xaas.Ultracode.Autonomic.backlog_script/1`):
# a repo alias may map to its own deterministic backlog script basename resolved
# from this app's priv/verifiers/; every unregistered alias (and the default)
# stays `aps_backlog.py`. Names only, never caller-supplied paths.
config :xaas, :ultracode_verifier_suites, %{}
config :xaas, :ultracode_backlog_scripts, %{}

# Out-of-band content pins for `Xaas.Pack.load/2`: the digest of
# ontology.ttl + the profile + gates/*.rq of each pinned capability pack.
# A pack whose bytes do not reproduce the committed literal is refused
# (`{:pack_digest_mismatch, pinned, observed}`). Re-pin deliberately, never
# from the loader.
config :xaas, :capability_pack_pins, %{
  "provider_status" => %{
    pack: "xaas_capability_pack",
    profile: "profiles/provider_status.ttl",
    digest: "sha256:ca8f9cd09fb2529a0be5b210b6a8874d9198b7184ea8d9d5997f38565dcc4946"
  },
  "ultracode" => %{
    pack: "xaas_capability_pack",
    profile: "profiles/ultracode.ttl",
    digest: "sha256:5a623257fe0fba9d9a44bf8d4c03fa3c3043ba0069e2e626f5d9bf8f439ffeb8"
  }
}

# The sensing-profile NAME registry (`Xaas.Ultracode.Sensing.profile/1`): a
# repo's registered `sensing:` name maps to a deterministic profile (the same
# shape `Sensing.derive/2` takes). Driven by the Autonomic sense stage's
# fallback when a repo's backlog script fails; an unmapped name stays a
# visible registration gap (`Repos.gaps/1`) and a typed sense refusal, never
# a silent skip. Environments that use it register named profiles in their
# own config file.
config :xaas, :ultracode_sensing_profiles, %{}
config :xaas, :ultracode_worktree_root, nil
config :xaas, :ultracode_ticket_dir, nil
# Opt-in module value (an atom, e.g. Xaas.Ultracode.TargetSuites) whose devs/0
# declares extra fabric verifier suites for non-APS targets; Xaas.Ultracode.
# Verifier resolves it at runtime, never at config-evaluation time. nil = no
# extra suites.
config :xaas, :ultracode_target_suites, nil
config :xaas, :ultracode_repos, %{}
config :xaas, :ultracode_sensing_profiles, %{}

# The engine's per-provider worker-slot bound (`Xaas.Ultracode.Lease.
# pool_capacity/1`, enforced race-free inside `claim_next/3`): 10 live
# leases per provider -- the operator-ordered standing wave size, now a
# real fence on EVERY claim path (MCP workers included), not just the
# wave's in-process semaphore. Integer = one bound for all providers; a
# map gives per-provider bounds (`%{"zcode" => 5, default: 3}`); nil =
# unbounded (the test-env choice, so `LeaseConcurrencyStressTest`'s
# 25-way claim storm keeps its exact semantics).
config :xaas, :ultracode_pool_capacity, 10

# Capability-resolution court (Xaas.Ultracode.CapabilityResolver).
#   * :ultracode_capability_sources -- nil = DERIVED default: the Local
#     run/census source always, plus Sa2a only when the endpoint below is
#     set. An unset endpoint is recorded on the receipt as
#     skipped/not_configured (counted: false) and does NOT fail the closure.
#     An explicit map (name => Source module) is taken verbatim, every
#     entry counted and fail-closed.
#   * :ultracode_sa2a_capability_endpoint -- SA2A fleet URL; nil = unset.
#     A set endpoint that errors fail-closes the court (:unresolved).
#   * :ultracode_capability_full_closure -- a COUNTED source returning
#     {:skipped, _} forces :unresolved when true (ctx may override).
config :xaas, :ultracode_capability_sources, nil
config :xaas, :ultracode_sa2a_capability_endpoint, nil
config :xaas, :ultracode_capability_full_closure, true

# Self-digest (Xaas.Ultracode.SelfDigestWorker / mix xaas.self_digest).
# telemetry_path nil => the wave loop's :ultracode_wave_loop_telemetry_path;
# admit: true persists recurring classified clusters as UltraCode self-work
# orders (ExperienceCluster -> Gap -> WorkOrder).
config :xaas, :ultracode_self_digest,
  telemetry_path: nil,
  out_dir: "tmp/self-digest",
  window_minutes: 1440,
  admit: true

# The provider registry + selection policy (`Xaas.Ultracode.ProviderRegistry`,
# closing UNSUPPORTED(provider-selection:policy)): one config map carrying ALL
# per-provider facets -- capabilities, transport descriptor, authority ceiling,
# receipt protocol, enabled kill switch, cost, concurrency. Selection
# (`ProviderRegistry.select/2`) admits only enabled providers whose
# capabilities cover the requirement and whose ceiling ranks at or above the
# required authority, ordered by policy (default ascending cost); an empty or
# exhausted registry is the typed `{:error, {:no_qualifying_provider, _}}` --
# never a silent default. The default provider for unsupplied callers is
# `:ultracode_default_provider` (the historical "zcode", named in exactly one
# place now). `concurrency` here is advisory; the ENFORCED per-provider slot
# bound remains `:ultracode_pool_capacity` above. The test env leaves the
# registry EMPTY (fail-closed: nothing selectable) and tests install their
# own entries via Application.put_env.
config :xaas, :ultracode_default_provider, "zcode"

# Wave loop in-flight worker bound (`Xaas.Ultracode.WaveLoop.acquire_slot/0`
# + step-selection exclusion). Must stay <= `:ultracode_pool_capacity`;
# declared above next to the Oban queue that shares the same value.
config :xaas, :ultracode_wave_loop_concurrency, wave_loop_concurrency

# Opt-in adaptive-width ceiling (`Xaas.Ultracode.WaveLoop.effective_concurrency/1`):
# the persisted setpoint may widen the loop's dispatch width up to this
# ceiling (+1 per clean pressure window, drain -4 at >=3 rate-kill
# signatures, floor 1). Default = the base `:ultracode_wave_loop_concurrency`
# above, so width only grows when an operator sets this key explicitly
# (never above `:ultracode_pool_capacity`). Intentionally NO default value
# is declared here: absent the key, growth is off.

# The zcode CLI checkout `Dispatch`/`ZcodePackage`/`ProviderHealth` admit the
# worker launcher from. `/Users/sac/dev/zcode-cli` (the v26.9.22-era default)
# was retired 2026-09-26 — 36 commits behind and subsumed by the canonical
# checkout; the same fact as `ZcodePackage.default_cli_dir/0`.
config :xaas, :ultracode_dispatch_cli_dir, "/Users/sac/zcode-cli"

# Subagent turn cap forwarded to every dispatched zcode worker
# (`Xaas.Ultracode.Dispatch.build/2` -> env `ZCODE_SUBAGENT_MAX_TURNS`).
# The vendored runtime reads it at the subagent child-session spawn site
# (zcode-cli src/max-turns.ts; precedence there: explicit env > the
# launcher's setting.json `subagents.maxTurns` lowering > upstream
# default 4). nil injects nothing: the worker then inherits whatever its
# launching environment exports, exactly as before this lever existed.
# Measured 2026-09-27 (zcode-cli, live cap=100): the cap counts the
# worker's own turns including the final report, so the value must
# exceed the longest planned sequential tool chain PLUS that report
# turn (a 100-call probe completed all 100 calls and was still killed
# before its report).
config :xaas, :ultracode_subagent_max_turns, nil

config :xaas, :ultracode_providers, %{
  "zcode" => %{
    capabilities: ["construction", "gall_work"],
    transport: %{kind: "zcode_cli"},
    authority_ceiling: :construction,
    receipt_protocol: "gall.work-receipt/1",
    enabled: true,
    cost: 1,
    concurrency: 5
  }
}

# The engine's worker seam (`Xaas.Ultracode.Engine.fill/1`) and the provider
# allowlist it fills on its own. The configured worker is the deterministic
# recipe provider (`Xaas.Ultracode.RecipeWorker`: registered argv, no model),
# and it is only ever handed epochs of allowlisted providers -- zcode (LLM)
# epochs are never discovered by the engine's undirected fill, so they are
# never dispatched to, declined by, and then reaped from the recipe worker.
config :xaas, :ultracode_engine_worker, {Xaas.Ultracode.RecipeWorker, :run}
config :xaas, :ultracode_engine_providers, ["recipe"]

# The deterministic construction recipe registry
# (`Xaas.Ultracode.RecipeWorker.recipe/1`): capability id (the work order's
# `sj:capabilityId`) => argv recipe, admitted by `TargetSuites.validate/1`
# plus a literal-argv check and run through `Verifier.spawn_and_collect/6`
# (`env -i` with ONLY this env, throwaway HOME/TMPDIR). Names only: a
# capability absent here is refused before any claim.
#
# "recipe:mix-format" -- the Friday reference KNOWN class (GC-FRI-0800 G6,
# GC23-5): `mix format` drift repair. The formatter's output is
# Elixir-version dependent, so the toolchain is the TARGET's:
# `elixir_toolchain: :target` makes `RecipeWorker.toolchain/1` resolve PATH
# per epoch from the target worktree's `.tool-versions` through the asdf
# install layout (absolute install dirs, because a throwaway HOME defeats
# asdf shims), else from the running node's `mix` + ERTS -- never a
# host-specific pin here (xaas CI runs setup-beam from .tool-versions, not
# asdf). The resolved identity lands in the lease evidence as `toolchain`.
config :xaas, :ultracode_construction_recipes, %{
  "recipe:mix-format" => %{
    elixir_toolchain: :target,
    env: %{"LANG" => "en_US.UTF-8"},
    steps: [%{id: "format", argv: ["mix", "format"], timeout_ms: 300_000}]
  }
}

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
