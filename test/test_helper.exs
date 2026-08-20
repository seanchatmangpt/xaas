# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
# Real, fixed test-only token for KanbanWeb.Plugs.RequireInternalApiToken --
# not a production secret (test env only), needed so real ConnCase tests
# against /internal-api and /api can authenticate for real rather than
# disabling the real gate for tests.
System.put_env("INTERNAL_API_TOKEN", "test-only-internal-api-token")

ExUnit.start()
# Real, concurrent-connection-pool-hungry stress tests are excluded by
# default -- run explicitly with `mix test --include stress`.
ExUnit.configure(exclude: [:stress])
Ecto.Adapters.SQL.Sandbox.mode(Kanban.Repo, :manual)
# ash-migration Phase 3: real, separate AshPostgres.Repo -- needed for any
# real Chicago-style test that touches Xaas.* Ash resources via the
# sandbox (Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo) in test setup).
Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
