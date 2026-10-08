defmodule Xaas.Generator.FamilyCourtW984gaTest do
  @moduledoc """
  W984ga unclaimed-family court over `test/support/generator.ex`
  (`Xaas.Generator`, the Ash.Generator-based fixture factory).

  The convenience wrappers (`create_user!/1`, `create_book!/1`,
  `create_org!/1`, `create_provider!/1`, `create_webhook!/1`,
  `pending_approval!/4`) are heavily exercised across the tree, but the
  *state-bearing branches behind them* are not: no test asserts (a) the
  typed uniqueness failure path through `create_org!/1` when the caller
  overrides `slug` with a duplicate (Org's `:unique_slug` identity),
  (b) the provider/org real-slug coupling (generator default is the
  placeholder `"org-generated"`), (c) the `enabled: false` webhook
  override persisting, or (d) the `normalize_email/1` no-email branch
  producing distinct persisted users via the sequence.

  Mutation rationale (per test): revert the named branch (drop the Org
  identity, or break overrides passthrough of `changeset_generator/3`
  `overrides: opts`, or drop the email sequence) and exactly this test
  fails while the existing tree stays green.
  """

  use XaasWeb.ConnCase

  alias Xaas.Accounts.{Org, User}
  alias Xaas.Generator
  alias Xaas.Library.Book
  alias Xaas.Marketplace.Provider
  alias Xaas.Platform.Webhook

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "create_org! with an explicitly duplicated slug fails with the real unique_slug identity error" do
    slug = "dup-org-#{System.unique_integer([:positive])}"

    org = Generator.create_org!(%{slug: slug})
    assert %Org{} = org
    assert org.slug == slug

    assert_raise Ash.Error.Invalid,
                 ~r/has already been taken/,
                 fn ->
                   Generator.create_org!(%{slug: slug})
                 end
  end

  test "create_provider! overrides bind the provider to a real org slug, not the org-generated placeholder" do
    org = Generator.create_org!()

    provider =
      Generator.create_provider!(%{
        org_id: org.slug,
        name: "court-provider-#{System.unique_integer([:positive])}"
      })

    assert %Provider{} = provider
    assert provider.org_id == org.slug
    refute provider.org_id == "org-generated"
  end

  test "create_webhook! honors the enabled: false override and persists it" do
    webhook =
      Generator.create_webhook!(%{
        enabled: false,
        org_id: "court-webhook-org-#{System.unique_integer([:positive])}"
      })

    assert %Webhook{} = webhook
    assert webhook.enabled == false

    reloaded = Ash.get!(Webhook, webhook.id, authorize?: false)
    assert reloaded.enabled == false
  end

  test "create_user! with no attrs yields two distinct persisted users (normalize_email/1 empty branch + email sequence)" do
    u1 = Generator.create_user!()
    u2 = Generator.create_user!()

    assert %User{} = u1
    assert %User{} = u2
    assert u1.id != u2.id
    assert u1.email != u2.email
    assert String.contains?(to_string(u1.email), "@example.com")

    assert Ash.get!(User, u1.id, authorize?: false).email == u1.email
  end

  test "create_book! override of copy counts persists through the real :create action" do
    book =
      Generator.create_book!(%{
        available_copies: 1,
        total_copies: 5,
        title: "W984ga Court Book"
      })

    assert %Book{} = book
    assert book.available_copies == 1
    assert book.total_copies == 5
    assert book.title == "W984ga Court Book"
  end
end
