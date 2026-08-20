# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Kanban.Repo, :manual)
# ash-migration Phase 3: real, separate AshPostgres.Repo -- needed for any
# real Chicago-style test that touches Xaas.* Ash resources via the
# sandbox (Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo) in test setup).
Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
