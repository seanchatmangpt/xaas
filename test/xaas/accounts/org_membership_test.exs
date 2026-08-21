defmodule Xaas.Accounts.OrgMembershipTest do
  @moduledoc """
  Real Chicago-style tests: real Ash actions against the real sandboxed
  Postgres (Xaas.Repo). No mocking. Users are real rows inserted via
  `Ash.Seed.seed!` (a real Ash-provided fixture mechanism that writes a
  real Postgres row bypassing User's auth-specific create actions, which
  need a real magic-link/password token this test has no reason to
  fabricate) -- not a mock or interaction double.
  """
  use ExUnit.Case, async: true

  alias Xaas.Accounts.{Org, OrgMembership, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_org!(slug_prefix) do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "Acme Inc",
      slug: "#{slug_prefix}-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_user!(email_prefix) do
    Ash.Seed.seed!(User, %{email: "#{email_prefix}-#{System.unique_integer([:positive])}@example.com"})
  end

  defp create_membership!(user, org, role \\ :member) do
    OrgMembership
    |> Ash.Changeset.for_create(:create, %{user_id: user.id, org_id: org.id, role: role})
    |> Ash.create!(authorize?: false)
  end

  test "a real membership can be created and read back via authorize?: false" do
    org = create_org!("acme")
    user = create_user!("alice")

    membership = create_membership!(user, org, :admin)

    assert membership.user_id == user.id
    assert membership.org_id == org.id
    assert membership.role == :admin

    persisted = OrgMembership |> Ash.get!(membership.id, authorize?: false)
    assert persisted.role == :admin
  end

  test "reads are bypassed to any actor (real, disclosed scope: read is not yet membership-scoped)" do
    org = create_org!("acme")
    user = create_user!("bob")
    membership = create_membership!(user, org)

    results = OrgMembership |> Ash.read!(actor: nil)
    assert Enum.any?(results, &(&1.id == membership.id))
  end

  test "an anonymous (actor-less) caller is really denied create -- not silently allowed" do
    org = create_org!("acme")
    user = create_user!("carol")

    changeset =
      OrgMembership
      |> Ash.Changeset.for_create(:create, %{user_id: user.id, org_id: org.id}, actor: nil)

    assert {:error, %Ash.Error.Forbidden{}} = Ash.create(changeset)
  end

  test "an anonymous (actor-less) caller is really denied update -- not silently allowed" do
    org = create_org!("acme")
    user = create_user!("dave")
    membership = create_membership!(user, org)

    changeset =
      membership
      |> Ash.Changeset.for_update(:update, %{role: :admin}, actor: nil)

    assert {:error, %Ash.Error.Forbidden{}} = Ash.update(changeset)

    persisted = OrgMembership |> Ash.get!(membership.id, authorize?: false)
    assert persisted.role == membership.role
  end

  test "the same user cannot be added to the same org twice -- real unique index enforced" do
    org = create_org!("acme")
    user = create_user!("erin")

    create_membership!(user, org)

    assert {:error, %Ash.Error.Invalid{}} =
             OrgMembership
             |> Ash.Changeset.for_create(:create, %{user_id: user.id, org_id: org.id})
             |> Ash.create(authorize?: false)
  end

  describe "Xaas.Accounts.Checks.ActorBelongsToOrg (via Org's :update policy)" do
    test "an actor with a real OrgMembership row for this org can update it" do
      org = create_org!("member-org")
      user = create_user!("frank")
      create_membership!(user, org, :admin)

      org
      |> Ash.Changeset.for_update(:update, %{name: "Renamed"}, actor: user)
      |> Ash.update!()

      # Read back via authorize?: false: the returned struct's :name field
      # itself is redacted (`Ash.ForbiddenField`) because Org's read
      # policy is separately IAM-gated and this plain `user` actor carries
      # no `iam_policy` -- unrelated to the :update policy under test.
      persisted = Org |> Ash.get!(org.id, authorize?: false)
      assert persisted.name == "Renamed"
    end

    test "an actor with no OrgMembership row for this org is really denied update" do
      org = create_org!("no-member-org")
      user = create_user!("grace")

      changeset =
        org
        |> Ash.Changeset.for_update(:update, %{name: "Hijacked"}, actor: user)

      assert {:error, %Ash.Error.Forbidden{}} = Ash.update(changeset)

      persisted = Org |> Ash.get!(org.id, authorize?: false)
      assert persisted.name == org.name
    end

    test "an actor with a membership in a different org cannot update this org" do
      org_a = create_org!("org-a")
      org_b = create_org!("org-b")
      user = create_user!("henry")
      create_membership!(user, org_a)

      changeset =
        org_b
        |> Ash.Changeset.for_update(:update, %{name: "Hijacked"}, actor: user)

      assert {:error, %Ash.Error.Forbidden{}} = Ash.update(changeset)
    end
  end
end
