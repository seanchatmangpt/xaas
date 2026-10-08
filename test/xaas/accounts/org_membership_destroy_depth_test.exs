defmodule Xaas.Accounts.OrgMembershipDestroyDepthTest do
  @moduledoc """
  W980i depth batch -- accounts surface. Chicago-style: real Ash actions on
  real sandboxed Postgres (`Xaas.Repo`), real `OrgMembership` rows, typed
  refusals. No mocks.

  Scope: the genuinely uncourted slice of the Org/OrgMembership lifecycle.
  `org_test.exs`/`org_membership_test.exs` (19 courts) already cover
  create/read/update + tenant-scoping; the `:destroy` default action and the
  `role` promote/demote lifecycle had zero prior coverage (verified by
  reading both files). Per-action coverage:

  - `:destroy` legitimate + anonymous-denied (row survives)
  - `role` promote/demote round trip via `:update` (authorize?: false)
  - `role` one_of constraint really refuses a bogus role

  Mutation rationale (W980i): delete `:destroy` from
  `defaults([:read, :destroy])` in `lib/xaus/accounts/org_membership.ex`
  -- the two destroy courts below fail (the action no longer exists), and
  the surviving-row assertion in the anonymous-denied court distinguishes a
  policy-shaped refusal (row survives) from an action-shaped one.
  """
  use ExUnit.Case, async: true

  alias Xaas.Accounts.{Org, OrgMembership, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_org! do
    Xaas.Generator.create_org!(%{
      name: "Acme Inc",
      slug: "w980i-org-#{System.unique_integer([:positive])}"
    })
  end

  defp create_user!(prefix) do
    Xaas.Generator.create_user!(%{
      email: "w980i-#{prefix}-#{System.unique_integer([:positive])}@example.com"
    })
  end

  defp create_membership!(user, org, role \\ :member) do
    OrgMembership
    |> Ash.Changeset.for_create(:create, %{user_id: user.id, org_id: org.id, role: role})
    |> Ash.create!(authorize?: false)
  end

  test "a real membership can be destroyed via authorize?: false and the row is really gone" do
    org = create_org!()
    user = create_user!("destroy-ok")
    membership = create_membership!(user, org)

    Ash.destroy!(membership, authorize?: false)

    assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
             OrgMembership |> Ash.get(membership.id, authorize?: false)
  end

  test "an anonymous caller is really denied destroy -- the row really survives" do
    org = create_org!()
    user = create_user!("denied-destroy")
    membership = create_membership!(user, org)

    assert {:error, %Ash.Error.Forbidden{}} = Ash.destroy(membership)

    persisted = OrgMembership |> Ash.get!(membership.id, authorize?: false)
    assert persisted.id == membership.id
  end

  test "role promotes member->admin and demotes back via :update (authorize?: false)" do
    org = create_org!()
    user = create_user!("promote")
    membership = create_membership!(user, org, :member)

    promoted =
      membership
      |> Ash.Changeset.for_update(:update, %{role: :admin}, authorize?: false)
      |> Ash.update!()

    assert promoted.role == :admin

    demoted =
      promoted
      |> Ash.Changeset.for_update(:update, %{role: :member}, authorize?: false)
      |> Ash.update!()

    assert demoted.role == :member

    persisted = OrgMembership |> Ash.get!(membership.id, authorize?: false)
    assert persisted.role == :member
  end

  test "role one_of constraint really refuses a bogus role value" do
    org = create_org!()
    user = create_user!("bogus-role")
    membership = create_membership!(user, org)

    assert {:error, %Ash.Error.Invalid{}} =
             membership
             |> Ash.Changeset.for_update(:update, %{role: :superadmin})
             |> Ash.update(authorize?: false)
  end
end
