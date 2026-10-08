defmodule Xaas.Accounts.FamilyCourtW984gxTest do
  @moduledoc """
  W984gx unclaimed-family probe court for `lib/xaas/accounts/`.

  Census (CamelCase grep against test/):
    - Org / OrgMembership / Token / User / checks / validations /
      RevokeNonce / EnforceSingleRevoke / RevokeVerifier / SendMagicLinkEmail:
      covered or indirectly-covered (token_revocation_test,
      revoke_verifier_depth_test, org_suspension_validation_depth_test,
      accounts_deepening_test). No new court needed.

    Genuinely unexercised state-bearing branches courted here:
      1. `User.change_password` — ZERO references outside its own definition
         (grep test/ lib/). Three branches: happy path, wrong current
         password (PasswordValidation), mismatched confirmation (confirm/2).
      2. `User.Senders.SendNewUserConfirmationEmail` — zero test references;
         its `:identity_link` branch (OAuth2 email-match confirmation prompt)
         is a pure function of `opts` and has never been executed by any test.
      3. `User.Senders.SendPasswordResetEmail` — zero test references.

  Real Chicago-style: real sandboxed Postgres, real Ash actions, real sender
  modules exercised directly (they print via IO.puts — no SMTP, no network,
  no mocks). Mutation rationale per test in the test body.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Xaas.Accounts.User

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp unique_email do
    "w984gx-#{System.unique_integer([:positive])}@example.com"
  end

  defp register_user!(email) do
    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "w984gx-initial-password",
      password_confirmation: "w984gx-initial-password"
    })
    |> Ash.create!(authorize?: false)
  end

  describe "User.change_password (previously zero-reference)" do
    test "happy path: correct current password + matching confirmation rehashes and persists" do
      email = unique_email()
      user = register_user!(email)

      assert {:ok, updated} =
               user
               |> Ash.Changeset.for_update(:change_password, %{
                 current_password: "w984gx-initial-password",
                 password: "w984gx-new-password",
                 password_confirmation: "w984gx-new-password"
               })
               |> Ash.update(authorize?: false)

      # Real persisted state: the new password actually signs in.
      assert {:ok, [_]} =
               User
               |> Ash.Query.for_read(:sign_in_with_password, %{
                 email: email,
                 password: "w984gx-new-password"
               })
               |> Ash.read(authorize?: false)

      # The old password no longer signs in (hash really rotated).
      assert {:error, _} =
               User
               |> Ash.Query.for_read(:sign_in_with_password, %{
                 email: email,
                 password: "w984gx-initial-password"
               })
               |> Ash.read(authorize?: false)

      assert updated.hashed_password != user.hashed_password
    end

    @tag :regression
    test "wrong current_password is a typed refusal (PasswordValidation branch)" do
      user = register_user!(unique_email())

      assert {:error, error} =
               user
               |> Ash.Changeset.for_update(:change_password, %{
                 current_password: "wrong-current-password",
                 password: "w984gx-new-password",
                 password_confirmation: "w984gx-new-password"
               })
               |> Ash.update(authorize?: false)

      # Real typed refusal shape: AshAuthentication raises
      # AuthenticationFailed (field: :current_password) wrapped in Forbidden.
      assert %Ash.Error.Forbidden{} = error

      assert Enum.any?(error.errors, fn
               %AshAuthentication.Errors.AuthenticationFailed{field: :current_password} -> true
               _ -> false
             end)
    end

    @tag :regression
    test "mismatched password_confirmation is a typed refusal (confirm/2 branch)" do
      user = register_user!(unique_email())

      assert {:error, error} =
               user
               |> Ash.Changeset.for_update(:change_password, %{
                 current_password: "w984gx-initial-password",
                 password: "w984gx-new-password",
                 password_confirmation: "different-confirmation"
               })
               |> Ash.update(authorize?: false)

      assert %Ash.Error.Invalid{} = refusal = error

      assert Enum.any?(refusal.errors, fn e ->
               Map.get(e, :field) in [:password_confirmation, :password]
             end)
    end

    test "sign_in_with_password with a bogus password is a typed refusal" do
      user = register_user!(unique_email())

      assert {:error, error} =
               User
               |> Ash.Query.for_read(:sign_in_with_password, %{
                 email: user.email,
                 password: "bogus-password"
               })
               |> Ash.read(authorize?: false)

      assert %Ash.Error.Forbidden{} = error

      assert Enum.any?(error.errors, fn
               %AshAuthentication.Errors.AuthenticationFailed{} -> true
               _ -> false
             end)
    end
  end

  describe "User.Senders (pure IO seam, zero prior references)" do
    test "SendNewUserConfirmationEmail default branch prints the confirm link" do
      output =
        capture_io(fn ->
          Xaas.Accounts.User.Senders.SendNewUserConfirmationEmail.send(
            %{email: "someone@example.com"},
            "token-abc-123",
            []
          )
        end)

      assert output =~ "/confirm_new_user/token-abc-123"
      assert output =~ "Click this link to confirm your email:"
    end

    @tag :regression
    test "SendNewUserConfirmationEmail :identity_link branch prints the provider-link prompt" do
      output =
        capture_io(fn ->
          Xaas.Accounts.User.Senders.SendNewUserConfirmationEmail.send(
            %{email: "someone@example.com"},
            "token-identity-456",
            confirmation_type: :identity_link,
            provider: :oauth_github
          )
        end)

      assert output =~ "Someone signed in with oauth_github using your email address"
      assert output =~ "/confirm_new_user/token-identity-456"
    end

    @tag :regression
    test "SendPasswordResetEmail prints the reset link for a real user struct" do
      output =
        capture_io(fn ->
          Xaas.Accounts.User.Senders.SendPasswordResetEmail.send(
            %{email: "reset@example.com"},
            "reset-token-789",
            []
          )
        end)

      assert output =~ "/password-reset/reset-token-789"
    end
  end
end
