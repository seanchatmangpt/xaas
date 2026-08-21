defmodule Xaas.Marketplace.ProviderTest do
  @moduledoc """
  Real Chicago-style tests: real `Ecto.Adapters.SQL.Sandbox`-backed
  Postgres (`Xaas.Repo`), real `Ash.Changeset.for_create` + `Ash.create!`/
  `Ash.read!` calls against the real `marketplace_providers` table. No
  mocking.
  """
  use ExUnit.Case, async: true
  require Ash.Query

  alias Xaas.Marketplace.Provider

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create!(attrs) do
    Provider
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  test "creating a provider persists real attributes with the real :pending default status" do
    org_id = "org-#{System.unique_integer([:positive])}"

    provider =
      create!(%{
        name: "Acme Widgets",
        slug: "acme-widgets-#{System.unique_integer([:positive])}",
        description: "Widgets as a service",
        org_id: org_id
      })

    assert provider.name == "Acme Widgets"
    assert provider.status == :pending
    assert provider.org_id == org_id
    assert provider.inserted_at != nil
    assert provider.updated_at != nil

    reread = Provider |> Ash.get!(provider.id, authorize?: false)
    assert reread.id == provider.id
  end

  test "slug uniqueness is really enforced" do
    slug = "dup-slug-#{System.unique_integer([:positive])}"
    create!(%{name: "First", slug: slug, org_id: "org-a"})

    assert {:error, %Ash.Error.Invalid{}} =
             Provider
             |> Ash.Changeset.for_create(:create, %{name: "Second", slug: slug, org_id: "org-b"})
             |> Ash.create(authorize?: false)
  end

  test "update transitions real status from :pending to :active" do
    provider =
      create!(%{name: "Beta Co", slug: "beta-co-#{System.unique_integer([:positive])}", org_id: "org-c"})

    updated =
      provider
      |> Ash.Changeset.for_update(:update, %{status: :active})
      |> Ash.update!(authorize?: false)

    assert updated.status == :active
  end

  test "an actor with a real Allow statement can read via the real AshIam.Check policy" do
    provider =
      create!(%{
        name: "Readable Co",
        slug: "readable-co-#{System.unique_integer([:positive])}",
        org_id: "org-readable"
      })

    actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["read"], "Resource" => ["xaas:marketplace_provider:*"]}
        ]
      }
    }

    results = Provider |> Ash.read!(actor: actor)
    assert Enum.any?(results, &(&1.id == provider.id))
  end

  test "an actor with no real iam_policy is really denied read -- not silently allowed" do
    _provider =
      create!(%{name: "Hidden Co", slug: "hidden-co-#{System.unique_integer([:positive])}", org_id: "org-d"})

    results = Provider |> Ash.read!(actor: %{})
    assert results == []
  end

  test "an actor whose Allow statement names a different provider's id cannot read this one" do
    visible =
      create!(%{
        name: "Visible Co",
        slug: "visible-co-#{System.unique_integer([:positive])}",
        org_id: "org-visible"
      })

    other =
      create!(%{
        name: "Other Co",
        slug: "other-co-#{System.unique_integer([:positive])}",
        org_id: "org-other"
      })

    scoped_actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["read"], "Resource" => ["xaas:marketplace_provider:#{visible.id}"]}
        ]
      }
    }

    results = Provider |> Ash.read!(actor: scoped_actor)
    assert Enum.any?(results, &(&1.id == visible.id))
    refute Enum.any?(results, &(&1.id == other.id))
  end
end
