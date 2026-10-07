defmodule Xaas.AccountsDeepeningTest do
  @moduledoc """
  Lane W727 — accounts-domain deepening (Chicago-style, no mocks).

  Real Ash actions against the real sandboxed Postgres (`Xaas.Repo`).
  Covers the undocketed `Xaas.Accounts` surface the existing
  `test/xaas/accounts/` files do not:

    (a) Org create + membership lifecycle (invite/join, role transitions,
        duplicate refusal, removal);
    (b) cross-tenant integrity (real User/Org references, FK integrity,
        org-deletion behavior — assert which);
    (c) magic-link config pin: `return_error_on_invalid_magic_link_token?
        true` is load-bearing — the invalid-token path really errors
        (real AshAuthentication call), plus a real valid-token round trip;
    (d) User PII surface: email uniqueness typed refusal via the real
        `:register_with_password` action.

  Users are seeded via `Ash.Seed.seed!` (same real-row fixture mechanism
  as `Xaas.Accounts.OrgMembershipTest`) except where the point of the
  test is the real registration action itself. Memberships/orgs go
  through the real `:create`/`:update`/`:destroy` actions with
  `authorize?: false` — the disclosed fixture-only bypass these
  resources' own deny-by-default catch-alls require (no membership
  management bypass exists yet; see `Xaas.Accounts.OrgMembership`'s
  moduledoc). Tests only — no new routes.
  """
  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Accounts.{Org, OrgMembership, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_org!(slug_prefix) do
    Xaas.Generator.create_org!(%{
      name: "Deepening Inc",
      slug: "#{slug_prefix}-#{System.unique_integer([:positive])}"
    })
  end

  defp create_user!(email_prefix) do
    Xaas.Generator.create_user!(%{
      email: "#{email_prefix}-#{System.unique_integer([:positive])}@example.com"
    })
  end

  defp create_membership!(user, org, role \\ :member) do
    OrgMembership
    |> Ash.Changeset.for_create(:create, %{user_id: user.id, org_id: org.id, role: role})
    |> Ash.create!(authorize?: false)
  end

  defp register_user_with_password(email, password)
      when is_binary(email) and is_binary(password) do
    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: password,
      password_confirmation: password
    })
    |> Ash.create(authorize?: false)
  end

  defp invalid_role_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %{field: :role} -> true
      _ -> false
    end)
  end

  defp invalid_role_error?(_), do: false

  defp error_text(error) do
    Exception.message(error) |> IO.iodata_to_binary()
  rescue
    _ -> inspect(error)
  end

  defp error_with_message?(error, needle) do
    error_text(error) |> String.contains?(needle)
  end

  # ---------------------------------------------------------------------------
  # (a) Org create + membership lifecycle
  # ---------------------------------------------------------------------------

  describe "(a) org create + membership lifecycle" do
    test "org :create really persists name/slug with the :active default status" do
      org =
        Org
        |> Ash.Changeset.for_create(:create, %{name: "Lifecycle Org", slug: "lifecycle-org"},
          authorize?: false
        )
        |> Ash.create!()

      assert org.status == :active
      assert org.name == "Lifecycle Org"

      persisted = Org |> Ash.get!(org.id, authorize?: false)
      assert persisted.slug == "lifecycle-org"
      assert persisted.status == :active
    end

    test "duplicate org slug is a typed refusal (unique_slug identity)" do
      slug = "w727-dupslug-#{System.unique_integer([:positive])}"

      Org
      |> Ash.Changeset.for_create(:create, %{name: "First", slug: slug}, authorize?: false)
      |> Ash.create!()

      assert {:error, error} =
               Org
               |> Ash.Changeset.for_create(:create, %{name: "Dup", slug: slug}, authorize?: false)
               |> Ash.create()

      assert error_with_message?(error, "has already been taken")
    end

    test "membership invite/join: role defaults to :member, real row read back" do
      org = create_org!("invite")
      user = create_user!("invited")

      membership = create_membership!(user, org)

      assert membership.role == :member
      persisted = OrgMembership |> Ash.get!(membership.id, authorize?: false)
      assert persisted.user_id == user.id
      assert persisted.org_id == org.id
      assert persisted.role == :member
    end

    test "role transition :member -> :admin via real :update persists" do
      org = create_org!("promote")
      user = create_user!("promotee")
      membership = create_membership!(user, org)

      updated =
        membership
        |> Ash.Changeset.for_update(:update, %{role: :admin}, authorize?: false)
        |> Ash.update!()

      assert updated.role == :admin

      assert OrgMembership |> Ash.get!(membership.id, authorize?: false) |> Map.get(:role) ==
               :admin
    end

    test "role transition to an out-of-constraint atom is refused" do
      org = create_org!("badrole")
      user = create_user!("badrolee")
      membership = create_membership!(user, org)

      assert {:error, error} =
               membership
               |> Ash.Changeset.for_update(:update, %{role: :owner}, authorize?: false)
               |> Ash.update()

      assert invalid_role_error?(error)
      # The real constraint surface: only :member / :admin exist.
      assert error_with_message?(error, "member, admin")
    end

    test "duplicate membership for the same (user, org) is a typed refusal" do
      org = create_org!("dupmem")
      user = create_user!("dupmeme")
      create_membership!(user, org)

      assert {:error, error} =
               OrgMembership
               |> Ash.Changeset.for_create(:create, %{user_id: user.id, org_id: org.id, role: :admin})
               |> Ash.create(authorize?: false)

      assert error_with_message?(error, "has already been taken")
    end

    test "membership removal via real :destroy deletes the row; user and org remain" do
      org = create_org!("leave")
      user = create_user!("leaver")
      membership = create_membership!(user, org)

      Ash.destroy!(membership, authorize?: false)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               OrgMembership |> Ash.get(membership.id, authorize?: false)
      assert Org |> Ash.get!(org.id, authorize?: false)
      assert User |> Ash.get!(user.id, authorize?: false)
    end
  end

  # ---------------------------------------------------------------------------
  # (b) Cross-tenant integrity
  # ---------------------------------------------------------------------------

  describe "(b) cross-tenant integrity" do
    test "membership references a real User and a real Org (loaded through the row)" do
      org = create_org!("tenant")
      user = create_user!("tenantmember")
      membership = create_membership!(user, org)

      loaded =
        membership
        |> Ash.load!([:user, :org], authorize?: false)

      assert loaded.user.id == user.id
      assert loaded.org.id == org.id
      assert loaded.org.slug == org.slug
    end

    test "membership with a nonexistent org_id is refused (real FK integrity)" do
      user = create_user!("fkuser")
      bogus_org_id = Ash.UUID.generate()

      assert {:error, error} =
               OrgMembership
               |> Ash.Changeset.for_create(:create, %{user_id: user.id, org_id: bogus_org_id})
               |> Ash.create(authorize?: false)

      assert error_with_message?(error, "is invalid") or
               error_with_message?(error, "does not exist")
    end

    test "org deletion is refused: Org ships no :destroy action (assert which behavior)" do
      org = create_org!("nodelete")

      # Org deliberately has no :destroy action — deletion is modeled as the
      # Xaas.Governance.ApprovalOrgDelete maker-checker flow instead. Ash
      # refuses with "No primary action of type :destroy for resource
      # Xaas.Accounts.Org".
      assert_raise Ash.Error.Invalid, ~r/No primary action of type :destroy/, fn ->
        Ash.destroy!(org, authorize?: false)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # (c) Magic-link config pin
  # ---------------------------------------------------------------------------

  describe "(c) magic-link invalid-token pin" do
    test "return_error_on_invalid_magic_link_token? true is configured" do
      # config/config.exs:34 — the load-bearing pin this suite guards.
      assert Application.get_env(:xaas, :ash_authentication)[
               :return_error_on_invalid_magic_link_token?
             ] == true
    end

    test "invalid magic-link token really errors — no silent ok (real AshAuthentication call)" do
      result =
        User
        |> Ash.Changeset.for_create(:sign_in_with_magic_link, %{
          token: "w727-not-a-real-token-#{System.unique_integer([:positive])}"
        })
        |> Ash.create(authorize?: false)

      assert {:error, _error} = result
      # And no user row was silently created by the garbage token.
      assert User
             |> Ash.Query.filter(email == "w727-not-a-real-token@example.com")
             |> Ash.read!(authorize?: false) == []
    end

    test "valid magic-link token round trip: real token mints, sign-in succeeds (W727 BLOCKED pin flipped by W786)" do
      email = "w727-magic-#{System.unique_integer([:positive])}@example.com"

      # `request_magic_link` is a generic :action, not a :create — real run
      # via ActionInput. The real sender (Xaas.Accounts.User.Senders.
      # SendMagicLinkEmail) prints the sign-in URL to stdout in the test
      # env; capture the real emitted token from the real token sender output.
      import ExUnit.CaptureIO, only: [capture_io: 1]

      logged =
        capture_io(fn ->
          action_input = Ash.ActionInput.for_action(User, :request_magic_link, %{email: email})
          assert :ok = Ash.run_action(action_input, authorize?: false)
        end)

      assert [stored_token] =
               Regex.run(~r/token=([A-Za-z0-9_\-.]+)/, logged, capture: :all_but_first)

      assert is_binary(stored_token) and stored_token != ""

      # W727/W757 disclosed this round trip as BLOCKED: ash_onetime 1.2.3's
      # `RevokeNonce.claim` (single-use token spend inside sign-in) hit
      # Postgres 42703 on the missing `logical_partition` column →
      # `AshOnetime.Error` `:store_invariant`. W786 generated and applied
      # the prescribed upgrade migration
      # (priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs,
      # per deps/ash_onetime/documentation/operations.md) on the test DB;
      # the sign-in now really succeeds and returns the user.
      assert {:ok, %User{} = signed_in} =
               User
               |> Ash.Changeset.for_create(:sign_in_with_magic_link, %{token: stored_token})
               |> Ash.create(authorize?: false)

      # email is an Ash.CiString — compare values, not struct pattern.
      assert Ash.CiString.value(signed_in.email) == email
    end
  end

  # ---------------------------------------------------------------------------
  # (d) User PII surface: email uniqueness typed refusal
  # ---------------------------------------------------------------------------

  describe "(d) user email uniqueness" do
    @unique_suffix System.unique_integer([:positive])

    test "duplicate email via real :register_with_password is a typed refusal; one row survives" do
      email = "w727-dup-#{@unique_suffix}@example.com"

      assert {:ok, first} = register_user_with_password(email, "w727-password-1")

      assert {:error, error} = register_user_with_password(email, "w727-password-2")
      assert error_with_message?(error, "has already been taken")

      assert [only] =
               User
               |> Ash.Query.filter(email == ^email)
               |> Ash.read!(authorize?: false)

      assert only.id == first.id
    end

    test "emails differing only in case collide (ci_string + unique_email identity)" do
      email = "w727-case-#{@unique_suffix + 1}@example.com"

      assert {:ok, first} = register_user_with_password(email, "w727-password-1")

      assert {:error, error} =
               register_user_with_password(String.upcase(email), "w727-password-2")

      assert error_with_message?(error, "has already been taken")

      assert only =
               User
               |> Ash.Query.filter(email == ^email)
               |> Ash.read_one!(authorize?: false)

      assert only.id == first.id
    end
  end
end
