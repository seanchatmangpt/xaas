# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :xaas, Xaas.LegacyRepo,
  username: System.get_env("DEV_DB_USERNAME", "postgres"),
  password: System.get_env("DEV_DB_PASSWORD", "postgres"),
  hostname: System.get_env("DEV_DB_HOSTNAME", "localhost"),
  port: String.to_integer(System.get_env("DEV_DB_PORT", "5432")),
  database: "xaas_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20

config :xaas, Xaas.Repo,
  username: System.get_env("DEV_DB_USERNAME", "postgres"),
  password: System.get_env("DEV_DB_PASSWORD", "postgres"),
  hostname: System.get_env("DEV_DB_HOSTNAME", "localhost"),
  port: String.to_integer(System.get_env("DEV_DB_PORT", "5432")),
  database: "xaas_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20,
  # Real fix: under the SQL Sandbox in shared mode every process shares ONE connection, so
  # concurrent Task.async_stream slot workers (Xaas.Ultracode.Engine.fill/1) queue on it.
  # DBConnection's defaults (queue_target 50ms / queue_interval 1000ms) drop those waiters
  # ("connection not available and request was dropped from queue after 281ms"), which made
  # test/xaas/ultracode/engine_test.exs "fill dispatches exactly the free slots ..." flake
  # with :handed_off instead of :done under CPU load. Guarded by
  # test/xaas/repo_test_pool_config_test.exs.
  queue_target: 5_000,
  queue_interval: 10_000,
  # Real fix: without this, Postgrex.DefaultTypes doesn't know how to
  # encode/decode the pgvector `vector` wire type -- every query touching
  # Book.embedding raises "type `vector` can not be handled by the types
  # module Postgrex.DefaultTypes". Xaas.PostgrexTypes (lib/xaas/postgrex_types.ex)
  # is a real Postgrex.Types.define/3 module registering
  # AshPostgres.Extensions.Vector alongside the standard Postgres extensions.
  types: Xaas.PostgrexTypes

# Same-service HMAC key for Xaas.Accounts.Token.RevokeVerifier's ash_onetime nonce
# protection on :revoke_token. Fixed test value; production reads it from env at
# runtime (config/runtime.exs).
config :xaas, Xaas.Accounts.Token,
  onetime_revoke_key: "test-only-onetime-revoke-key-do-not-use-in-prod"

config :xaas,
  token_signing_secret: "test-token-signing-secret-at-least-32-bytes-long-for-jwt-signing!!"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :xaas, XaasWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "R0hv8DBm2eLIGQsu63NgN+Na/ZLpvVaZ0lU3P2XHhYL7qwQf4o802taC0lfEF12L",
  server: false

# Compile the same dev-only routes (live_dashboard, ash_admin, and this
# session's autofde-lab dashboard LiveView) under test as under dev, so
# Phoenix.LiveViewTest can real-mount them -- same compile-time guard,
# same dev/test-only trust boundary, never set true in prod.
config :xaas, dev_routes: true

# In test we don't send emails.
config :xaas, Xaas.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Real Req retry behavior (same attempt count, same real
# Req.TransportError{reason: :econnrefused} path) but with zero backoff
# delay -- collapses prometheus_query_controller_test.exs's two real
# retry-exhaustion tests from ~6.6s each to a few ms without faking the
# retry count or the transport error itself.
config :req, default_options: [retry_delay: fn _n -> 0 end]

# ULTRACODE-50 milestone (2026-09-14): Oban is now actually supervised
# (lib/xaas/application.ex) -- previously it wasn't, so this override was
# never needed. `testing: :manual` disables the real Cron/queue
# supervisors during tests (they'd otherwise try to check out an
# Ecto.Adapters.SQL.Sandbox connection outside any test process's
# ownership and hang/error) while keeping every existing test's own
# direct calls into the underlying action/Reactor code paths real and
# unaffected -- those tests never depended on Oban's own scheduler firing,
# only on the admitted actions the scheduler would eventually call.
config :xaas, Oban, testing: :manual

# Pool capacity is UNBOUNDED in tests: production pins 5 (the operator's
# standing wave size, enforced in `Xaas.Ultracode.Lease.claim_next/3`), but
# every existing claim-side test (including `LeaseConcurrencyStressTest`'s
# 25-way one-provider claim storm, `--include stress`) asserts its exact
# semantics against an unbounded pool. Tests that qualify the capacity
# fence itself set it explicitly (per-call `:pool_capacity` opt or an
# `Application.put_env` + `on_exit` restore), the same pattern
# `:ultracode_provider_tools` tests use.
config :xaas, :ultracode_pool_capacity, nil

# The provider registry is EMPTY in tests (fail-closed: nothing is
# selectable until a test installs entries). Production's config.exs pins a
# real "zcode" entry; here every registry-consuming test writes its own
# entries via `Application.put_env(:xaas, :ultracode_providers, ...)` +
# `on_exit` restore (the same pattern `:ultracode_provider_tools` tests
# use). `:ultracode_default_provider` stays "zcode" (inherited from
# config.exs) so the unsupplied-provider default keeps its historical
# value everywhere the registry is not under test.
config :xaas, :ultracode_providers, %{}

# Test-only real OTel SDK config for
# test/xaas/telemetry/ocel_real_otel_span_test.exs: configuring ANY
# processor here just ensures :opentelemetry's real supervision tree
# actually starts the :otel_simple_processor_global gen_statem process at
# app boot -- the exporter target below is a real, valid placeholder
# (this config-loading process, not any real test process); each test
# re-points it to its own pid at runtime via the real
# :otel_simple_processor.set_exporter/2 API before exercising anything.
config :opentelemetry,
  processors: [
    {:otel_simple_processor, %{exporter: {:otel_exporter_pid, self()}}}
  ]
