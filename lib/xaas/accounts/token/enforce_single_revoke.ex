defmodule Xaas.Accounts.Token.EnforceSingleRevoke do
  @moduledoc """
  Real `Ash.Resource.Change` wiring `ash_onetime`'s one-time-nonce protection into
  `Xaas.Accounts.Token`'s `:revoke_token` action.

  Runs a real `Ash.create/2` against `Xaas.Accounts.Token.RevokeNonce`'s ash_onetime-protected
  `:claim` action, keyed on the raw token string being revoked, before the revocation record
  is written. The first call for a given token string claims the nonce and proceeds; every
  later call for the *same* token string fails closed with `AshOnetime.Error`'s
  `:nonce_already_used` code, added to the changeset as `:token` error, before
  `AshAuthentication.TokenResource.RevokeTokenChange` runs.
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Xaas.Accounts.Token.RevokeNonce

  @impl true
  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, &claim_nonce/1, prepend?: true)
  end

  defp claim_nonce(changeset) do
    token = Changeset.get_argument(changeset, :token)

    RevokeNonce
    |> Ash.Changeset.for_create(:claim, %{token: token})
    |> Ash.create()
    |> case do
      {:ok, _nonce} ->
        changeset

      {:error, error} ->
        message =
          case AshOnetime.Error.code(error) do
            :nonce_already_used -> "this token has already been revoked"
            _other -> "revocation could not be admitted"
          end

        Changeset.add_error(changeset,
          field: :token,
          message: message
        )
    end
  end
end
