# e2e/seed-library.exs — W823 next-read seed (v26.10.6).
#
# Run via: PATH="$HOME/.asdf/shims:$PATH" MIX_ENV=dev mix run e2e/seed-library.exs
#
# W752's e2e validation found failure class next-read-ml x3: an e2e boot
# serving an unseeded database shows 0 `library_books` on /next-read, so
# every spec that needs a card (why-button, pin, checkout, ask-results)
# found an empty shelf.
#
# W984fw: this seed and the Playwright webServer are both PINNED to
# MIX_ENV=dev (xaas_dev). The previous MIX_ENV=test wiring committed
# unsandboxed rows into xaas_test — including foreign
# liveview_librarian/toggle_pin Curation rows from the next-read-ml pin
# click (W650h23 root cause).
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
# W984lr: guard behind Mix.env == :test — under the W984fw MIX_ENV=dev
# pinned boot the dev Repo is not sandbox-pooled, so the unconditional flip
# raised and W823_SEED_OK was never reported (W984lp finding).
if Mix.env() == :test do
  Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :auto)
  Ecto.Adapters.SQL.Sandbox.mode(Xaas.LegacyRepo, :auto)
end

# Explicit `e2e: true` opt-in (lane W984bs): DevSeeds' environment guard
# (W983f) refuses unsandboxed :test-env calls with
# `REFUSED(dev_seeds, env=test)`. This script IS the sanctioned committed
# e2e boot seed -- Verified 2026-10-08 (W984fw): both this seed and the
# Playwright webServer are PINNED to MIX_ENV=dev (xaas_dev), so the fixtures
# land in the same database the server serves. The `e2e: true` opt-in below
# only matters if someone runs this script in :test env; the guard's
# :test + sandbox-owner branch keeps dev_seeds_test.exs courts green.
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

# W984lr: read-first, not read_one! — legacy xaas_dev state has multiple
# Curation rows per cartographer book_id (playwright pin toggles), and
# read_one! raises on ambiguity, so the re-assert was not idempotent.
case Xaas.Library.Curation
     |> Ash.Query.filter(book_id == ^cartographer.id)
     |> Ash.Query.limit(1)
     |> Ash.read!(authorize?: false)
     |> List.first() do
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
