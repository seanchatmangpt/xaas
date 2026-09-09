# ---
# Shared Chicago-style test fixture factory.
#
# Found via a real audit (this session): 20+ test files independently
# reimplemented near-identical `create_book!`/`create_user!` private
# functions, and they had genuinely drifted from each other (different
# `grade_level` types -- integer vs. `Decimal.new/1` -- different
# `available_copies`/`total_copies` defaults, one file bypassing Ash
# entirely via a raw SQL INSERT for `create_user!` to work around a
# schema-drift bug that's since been fixed). One shared factory is the
# real fix: one source of truth per resource, migrated as files are
# touched rather than all at once.
# ---
defmodule Xaas.Factory do
  @moduledoc """
  Shared Ash-backed fixture builders for tests. Every function calls the
  real Ash action (`Ash.Seed.seed!`/`Ash.create!`) against the real
  sandboxed Postgres -- no mocking, matching this repo's Chicago-style
  testing discipline. `attrs` is a map of overrides merged over the
  defaults below; pass only what a given test actually needs to vary.
  """

  alias Xaas.Accounts.User
  alias Xaas.Library.Book

  @doc "Real Ash.Seed-created Xaas.Accounts.User."
  def create_user!(attrs \\ %{}) do
    email = Map.get(attrs, :email) || Faker.Internet.email()
    Ash.Seed.seed!(User, Map.merge(%{email: email}, Map.delete(attrs, :email)))
  end

  @doc """
  Real Ash-created Xaas.Library.Book. `grade_level` is always an integer
  (the resource's real attribute type) -- pass an integer override, not a
  `Decimal`, for consistency with the majority of existing callers.
  """
  def create_book!(attrs \\ %{}) do
    available_copies = Map.get(attrs, :available_copies, 2)
    total_copies = Map.get(attrs, :total_copies, max(available_copies, 2))

    defaults = %{
      title: Faker.Commerce.product_name(),
      author: Faker.Person.name(),
      isbn: Faker.Commerce.color() <> "-#{System.unique_integer([:positive])}",
      grade_level: Enum.random(3..8),
      genres: ["Fiction", "Adventure"],
      synopsis: Faker.Lorem.paragraph(2),
      available_copies: available_copies,
      total_copies: total_copies
    }

    Book
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
    |> Ash.create!(authorize?: false)
  end
end
