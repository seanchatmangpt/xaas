# ---
# Idiomatic Ash test fixtures via Ash.Generator -- the framework's own
# built-in tool for this exact problem (StreamData-backed seed/changeset
# generators, `sequence/3` for unique values, `generate/1` to
# materialize). Replaces the hand-rolled Xaas.Factory this session
# initially wrote before checking whether Ash itself already solved
# fixture duplication/drift -- it does (deps/ash/lib/ash/generator/
# generator.ex).
# ---
defmodule Xaas.Generator do
  @moduledoc """
  Shared Ash.Generator-based fixture generators for tests, per Ash's own
  documented pattern (`Ash.Generator`'s moduledoc): `use Ash.Generator`,
  define functions using `seed_generator/2` (bypasses actions, direct
  data-layer insert) or `changeset_generator/3` (calls a real action via
  `generate/1`), then `import Xaas.Generator` in a test and call
  `generate(book())`/`generate(user())` etc.

  Also exposes `create_book!/1` and `create_user!/1` convenience
  wrappers (`generate(book(attrs))`/`generate(user(attrs))`) so files
  already migrated to the old hand-rolled `Xaas.Factory` call surface
  don't need a second migration.
  """

  use Ash.Generator

  alias Xaas.Accounts.{Org, User}
  alias Xaas.Library.Book
  alias Xaas.Marketplace.Provider
  alias Xaas.Platform.Webhook

  @doc """
  Real Ash.Seed-backed User generator (`Ash.Seed.seed!` under the hood,
  via `seed_generator/2` -- bypasses actions/policies, matching this
  repo's existing convention of seeding users directly).
  """
  def user(opts \\ []) do
    seed_generator(
      %User{
        email:
          sequence(:user_email, &"user-#{&1}-#{System.unique_integer([:positive])}@example.com")
      },
      overrides: opts
    )
  end

  @doc "Convenience: generate/1 a single real User row."
  def create_user!(attrs \\ %{}) do
    generate(user(Map.to_list(normalize_email(attrs))))
  end

  defp normalize_email(%{email: email}) when is_binary(email), do: %{email: email}
  defp normalize_email(_attrs), do: %{}

  @doc """
  Real Ash-action-backed Book generator (`changeset_generator/3`, so it
  goes through the real `:create` action -- validations/changes run for
  real, matching this repo's Chicago-style discipline). `sequence/3`
  gives each generated book a real, unique title/isbn without every
  caller re-deriving `System.unique_integer/1` by hand.
  """
  def book(opts \\ []) do
    changeset_generator(
      Book,
      :create,
      authorize?: false,
      defaults: [
        title: sequence(:book_title, &"Generated Book #{&1}"),
        author: StreamData.repeatedly(fn -> Faker.Person.name() end),
        isbn: sequence(:book_isbn, &"generated-isbn-#{&1}-#{System.unique_integer([:positive])}"),
        grade_level: StreamData.integer(3..8),
        genres: StreamData.constant(["Fiction", "Adventure"]),
        synopsis: StreamData.repeatedly(fn -> Faker.Lorem.paragraph(2) end),
        available_copies: StreamData.constant(2),
        total_copies: StreamData.constant(2)
      ],
      overrides: opts
    )
  end

  @doc "Convenience: generate/1 a single real Book row via the real :create action."
  def create_book!(attrs \\ %{}) when is_map(attrs) do
    generate(book(Map.to_list(attrs)))
  end

  @doc """
  Real Ash-action-backed Org generator (`changeset_generator/3`, real
  `:create` action, `authorize?: false` since Org is the tenant root and
  these fixtures are meant to bypass policy). `sequence/3` gives each
  generated org a real, unique slug.
  """
  def org(opts \\ []) do
    changeset_generator(
      Org,
      :create,
      authorize?: false,
      defaults: [
        name: StreamData.constant("Test Org"),
        slug: sequence(:org_slug, &"org-#{&1}-#{System.unique_integer([:positive])}")
      ],
      overrides: opts
    )
  end

  @doc "Convenience: generate/1 a single real Org row via the real :create action."
  def create_org!(attrs \\ %{}) when is_map(attrs) do
    generate(org(Map.to_list(attrs)))
  end

  @doc """
  Real Ash-action-backed Provider generator (`changeset_generator/3`,
  real `:create` action, `authorize?: false` for fixture purposes).
  `sequence/3` gives each generated provider a real, unique slug.
  """
  def provider(opts \\ []) do
    changeset_generator(
      Provider,
      :create,
      authorize?: false,
      defaults: [
        name: StreamData.constant("Test Provider"),
        slug: sequence(:provider_slug, &"provider-#{&1}-#{System.unique_integer([:positive])}"),
        org_id: StreamData.constant("org-generated")
      ],
      overrides: opts
    )
  end

  @doc "Convenience: generate/1 a single real Provider row via the real :create action."
  def create_provider!(attrs \\ %{}) when is_map(attrs) do
    generate(provider(Map.to_list(attrs)))
  end

  @doc """
  Real Ash-action-backed Webhook generator (`changeset_generator/3`,
  real `:create` action, `authorize?: false` for fixture purposes).
  `sequence/3` gives each generated webhook a real, unique listener
  URL/org_id.
  """
  def webhook(opts \\ []) do
    changeset_generator(
      Webhook,
      :create,
      authorize?: false,
      defaults: [
        org_id: sequence(:webhook_org_id, &"webhook-test-org-#{&1}"),
        url:
          sequence(:webhook_url, &"http://127.0.0.1:9#{rem(&1, 999)}#{System.unique_integer([:positive])}/"),
        event_types: StreamData.constant(["test.event"]),
        secret: StreamData.constant("real-hmac-secret"),
        enabled: StreamData.constant(true)
      ],
      overrides: opts
    )
  end

  @doc "Convenience: generate/1 a single real Webhook row via the real :create action."
  def create_webhook!(attrs \\ %{}) when is_map(attrs) do
    generate(webhook(Map.to_list(attrs)))
  end

  @doc """
  Generic pending-approval builder for the `Approval*` resource family
  (`ApprovalPricingOverride`, `ApprovalBackupRetentionChange`,
  `ApprovalTierDowngrade`, etc.) -- one function instead of ~8, since the
  target resource module varies per caller but the real shape (a real
  `:create`-action-backed row, `authorize?: false` for fixture purposes)
  is identical across all of them. `resource` is the target `Approval*`
  module; `action` defaults to `:create`; `attrs` is passed straight
  through to `Ash.Changeset.for_create/3` (callers supply the specific
  required attrs for their resource, e.g. `requested_by`, `org_id`,
  `tenant:` opts as needed via `opts`).
  """
  def pending_approval!(resource, action \\ :create, attrs \\ %{}, opts \\ []) do
    resource
    |> Ash.Changeset.for_create(action, attrs, opts)
    |> Ash.create!(authorize?: false)
  end
end
