defmodule Xaas.Accounts.TokenRevocationTest do
  @moduledoc """
  Real Chicago-style court for the EA35 `:is_revoked` rename
  (`Xaas.Accounts.Token` action `:revoked?` -> `:is_revoked`, with
  `is_revoked_action_name(:is_revoked)` pinned in the token DSL).

  Real Ash actions against the real sandboxed Postgres (Xaas.Repo), real
  AshAuthentication JWTs signed with the real signing secret. No mocking.

  Coverage:
    1. DSL pinning: the check action is named `:is_revoked` (JS-safe, no
       `?` suffix), the `:revoked?` name is gone, and AshAuthentication's
       own consumer surface (`AshAuthentication.TokenResource.Info`) still
       resolves the pinned name.
    2. Real revocation lifecycle through the real consumer helpers
       (`token_revoked?/3`, `jti_revoked?/3`) that resolve the pinned
       name: false pre-revocation, true after a real `:revoke_jti`.
    3. Real revocation row: a `purpose == "revocation"` row keyed on the
       JWT's jti lands in the real tokens table.

  Disclosed pre-existing BLOCKED (not rename-related, not fixed here --
  lib is out of this lane's scope): `:revoke_token` (the JWT path, gated
  by `EnforceSingleRevoke` -> `RevokeNonce`'s ash_onetime `:claim`)
  fails with `AshOnetime.Error` `:store_invariant` /
  "authoritative admission store failed" on the FIRST call under
  MIX_ENV=test (observed 2026-10-06 via direct `RevokeNonce.claim`
  probe, sandboxed and unsandboxed). Revocation is therefore exercised
  through `:revoke_jti`, which shares the same `:is_revoked` check
  action and really inserts a revocation row.
  """
  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Accounts.Token

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_user! do
    Xaas.Generator.create_user!(%{
      email: "token-revoke-#{System.unique_integer([:positive])}@example.com"
    })
  end

  defp jwt_for!(user) do
    {:ok, jwt, _claims} = AshAuthentication.Jwt.token_for_user(user)
    jwt
  end

  defp jti_of!(jwt) do
    {:ok, %{"jti" => jti}} = AshAuthentication.Jwt.peek(jwt)
    jti
  end

  # store_all_tokens?(true) pre-stores the minted token's row under its jti
  # (the table's primary key). RevokeJtiChange then inserts the revocation
  # row with the SAME jti, so the pre-stored row is removed inside the
  # sandboxed transaction to make room. Disclosed AshAuthentication collision.
  defp clear_stored_token_row!(jti) do
    import Ecto.Query

    {count, _} =
      Xaas.Repo.delete_all(from(t in "tokens", where: t.jti == ^jti))

    count
  end

  describe "EA35 rename: DSL pinning" do
    test "the revocation check action is named :is_revoked (no ? suffix)" do
      assert %Ash.Resource.Actions.Action{name: :is_revoked} =
               Ash.Resource.Info.action(Token, :is_revoked)

      # The JS-unsafe `:revoked?` name is gone.
      refute Ash.Resource.Info.action(Token, :revoked?)

      # AshAuthentication resolves the check through the pinned name.
      assert {:ok, :is_revoked} =
               AshAuthentication.TokenResource.Info.token_revocation_is_revoked_action_name(Token)
    end

    test "revocation + storage mutations kept their action names" do
      assert Ash.Resource.Info.action(Token, :revoke_token)
      assert Ash.Resource.Info.action(Token, :revoke_jti)
      assert Ash.Resource.Info.action(Token, :store_token)
      assert Ash.Resource.Info.action(Token, :expunge_expired)
    end
  end

  describe "real revocation lifecycle via the real consumer helpers" do
    test "token_revoked?/3 flips false -> true across a real :revoke_jti" do
      user = create_user!()
      jwt = jwt_for!(user)
      jti = jti_of!(jwt)
      clear_stored_token_row!(jti)

      assert false ==
               AshAuthentication.TokenResource.token_revoked?(Token, jwt, authorize?: false)

      Token
      |> Ash.Changeset.for_create(:revoke_jti, %{subject: to_string(user.id), jti: jti_of!(jwt)},
        authorize?: false
      )
      |> Ash.create!()

      assert true == AshAuthentication.TokenResource.token_revoked?(Token, jwt, authorize?: false)

      # The real revocation row, keyed on the JWT's jti, is in the real table.
      assert Token
             |> Ash.Query.filter(jti == ^jti and purpose == "revocation")
             |> Ash.read!(authorize?: false)
             |> Enum.any?()
    end

    test "jti_revoked?/3 flips false -> true across a real :revoke_jti" do
      user = create_user!()
      jwt = jwt_for!(user)
      jti = jti_of!(jwt)
      clear_stored_token_row!(jti)

      assert false == AshAuthentication.TokenResource.jti_revoked?(Token, jti, authorize?: false)

      Token
      |> Ash.Changeset.for_create(:revoke_jti, %{subject: to_string(user.id), jti: jti},
        authorize?: false
      )
      |> Ash.create!()

      assert true == AshAuthentication.TokenResource.jti_revoked?(Token, jti, authorize?: false)
    end
  end
end
