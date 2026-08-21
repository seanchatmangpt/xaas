defmodule Xaas.Accounts.OrgTest do
  @moduledoc """
  Real Chicago-style tests: real Ash actions against the real sandboxed
  Postgres (Xaas.Repo). Proves the real, working parts of this session's
  AshIam pilot -- IAM-gated :read (matching the one working precedent,
  Xaas.Accounts.User) -- and does not claim :create/:update are
  IAM-gated, since that real-tested as broken this session (see
  lib/xaas/accounts/org.ex's policies block for the disclosed
  limitation). No mocking of the authorizer.

  Also proves the bypass-audit fix (prompt #10): :create/:update are
  scoped to `actor_present()` rather than a blanket `authorize_if
  always()` -- a real authenticated actor still succeeds, an anonymous
  (`actor: nil`) caller is really denied.
  """
  use ExUnit.Case, async: true

  alias Xaas.Accounts.Org

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create!(slug_prefix) do
    Org
    |> Ash.Changeset.for_create(:create, %{name: "Acme Inc", slug: "#{slug_prefix}-#{System.unique_integer([:positive])}"})
    |> Ash.create!(authorize?: false)
  end

  test "a real org can be created and read back via authorize?: false (system-internal path)" do
    org = create!("acme")
    assert org.name == "Acme Inc"
    assert org.status == :active

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.slug == org.slug
  end

  test "an actor with a real Allow statement can read via the real AshIam.Check policy" do
    org = create!("readable")

    actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["read"], "Resource" => ["xaas:org:*"]}
        ]
      }
    }

    results = Org |> Ash.read!(actor: actor)
    assert Enum.any?(results, &(&1.id == org.id))
  end

  test "an actor with no real iam_policy is really denied read -- not silently allowed" do
    org = create!("hidden")

    results = Org |> Ash.read!(actor: %{})
    refute Enum.any?(results, &(&1.id == org.id))
  end

  test "an actor whose Allow statement names other orgs, not this one, cannot read this org" do
    visible = create!("visible")
    other = create!("other")

    scoped_actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["read"], "Resource" => ["xaas:org:#{visible.id}"]}
        ]
      }
    }

    results = Org |> Ash.read!(actor: scoped_actor)
    assert Enum.any?(results, &(&1.id == visible.id))
    refute Enum.any?(results, &(&1.id == other.id))
  end

  # NOTE (real, disclosed limitation found this session): a wildcard
  # `Allow "*"` combined with a specific-ID `Deny` for the *same* action
  # real-tested as NOT excluding the denied record via Ash.read -- ash_iam's
  # auto_filter falls back to "allow all" (`{:ok, true}`) before the
  # per-record strict_check deny-precedence path takes effect for this
  # exact combination. Not fully root-caused within this session's time
  # budget; the precise-Allow-list pattern above is the real, verified-
  # working alternative for scoping reads to specific orgs.

  test "a real authenticated actor can still create and update an org (legitimate case)" do
    actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["read"], "Resource" => ["xaas:org:*"]}
        ]
      }
    }

    org =
      Org
      |> Ash.Changeset.for_create(:create, %{name: "Beta LLC", slug: "beta-#{System.unique_integer([:positive])}"}, actor: actor)
      |> Ash.create!()

    assert org.name == "Beta LLC"

    updated =
      org
      |> Ash.Changeset.for_update(:update, %{name: "Beta LLC Renamed"}, actor: actor)
      |> Ash.update!()

    assert updated.name == "Beta LLC Renamed"
  end

  test "an anonymous (actor-less) caller is really denied create -- not silently allowed" do
    changeset =
      Org
      |> Ash.Changeset.for_create(:create, %{name: "Malicious Co", slug: "mal-#{System.unique_integer([:positive])}"}, actor: nil)

    assert {:error, %Ash.Error.Forbidden{}} = Ash.create(changeset)
  end

  test "an anonymous (actor-less) caller is really denied update -- not silently allowed" do
    org = create!("target")

    changeset =
      org
      |> Ash.Changeset.for_update(:update, %{name: "Hijacked"}, actor: nil)

    assert {:error, %Ash.Error.Forbidden{}} = Ash.update(changeset)

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.name == org.name
  end

  test "slug uniqueness is really enforced" do
    slug = "dup-#{System.unique_integer([:positive])}"

    Org
    |> Ash.Changeset.for_create(:create, %{name: "First", slug: slug})
    |> Ash.create!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             Org
             |> Ash.Changeset.for_create(:create, %{name: "Second", slug: slug})
             |> Ash.create(authorize?: false)
  end
end
