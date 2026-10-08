# e2e/seed-library.exs — W823 next-read test-env seed (v26.10.6).
#
# Run via: PATH="$HOME/.asdf/shims:$PATH" MIX_ENV=test mix run e2e/seed-library.exs
#
# W752's e2e validation found failure class next-read-ml x3: the e2e boot
# under MIX_ENV=test serves the /next-read LiveView from xaas_test, which
# has 0 `library_books` (vs 18 in xaas_dev), so every spec that needs a
# card (why-button, pin, checkout, ask-results) found an empty shelf.
#
# This script seeds the REAL app fixture chain -- `Xaas.DevSeeds.run/0`
# (the same chain `priv/repo/seeds.exs` runs in dev: real Ash actions with
# `authorize?: false`, idempotent lookups by natural key, plus the one
# documented raw users insert for the dev reader) -- into whichever
# database MIX_ENV selects. No raw SQL fixture dumping of library rows.
#
# Sandbox note: config/test.exs puts Xaas.Repo in Ecto SQL Sandbox
# :manual mode; a `mix run` script process owns no sandbox connection, so
# we flip the ownership mode to :auto first (script-only, never inherited
# by the `mix test` suite, which keeps :manual via test/test_helper.exs).
Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Xaas.LegacyRepo, :auto)

# Explicit `e2e: true` opt-in (lane W984bs): DevSeeds' environment guard
# (W983f) refuses unsandboxed :test-env calls with
# `REFUSED(dev_seeds, env=test)`. This script IS the sanctioned committed
# e2e boot seed -- it deliberately writes the fixture chain to the test
# database the Playwright webServer serves from -- so it opts in by name.
fixtures = Xaas.DevSeeds.run(e2e: true)

# Determinism across runs: DevSeeds.get_or_create_library_curations/1 is
# get-or-create by book_id, so if an earlier run's spec click UNPINNED the
# seeded cartographer spotlight, a rerun would silently keep it inactive and
# the ranker's curation_score input would stay dead. Re-assert the fixture's
# documented pinned state (real Ash update, same authorize?: false
# convention as DevSeeds itself).
require Ash.Query

cartographer =
  Xaas.Library.Book
  |> Ash.Query.filter(isbn == "978-0-000-00003-5")
  |> Ash.read_one!(authorize?: false)

case Xaas.Library.Curation
     |> Ash.Query.filter(book_id == ^cartographer.id)
     |> Ash.read_one!(authorize?: false) do
  nil ->
    :ok

  curation when curation.active and curation.state == :pinned ->
    :ok

  curation ->
    curation
    |> Ash.Changeset.for_update(:update, %{active: true, state: :pinned},
      authorize?: false
    )
    |> Ash.update!(authorize?: false)
end

IO.puts("W823_SEED_OK #{length(fixtures.library_books)} library_books seeded")
