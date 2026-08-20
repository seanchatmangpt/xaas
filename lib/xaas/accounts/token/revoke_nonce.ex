defmodule Xaas.Accounts.Token.RevokeNonce do
  @moduledoc """
  ash_onetime-protected nonce ledger for `Xaas.Accounts.Token`'s `:revoke_token` action.

  `Xaas.Accounts.Token` itself cannot carry `AshOnetime.Resource`: it has a required
  `:expires_at` attribute, and `:expires_at` is one of `AshOnetime.reserved_verification_inputs/0`'s
  five reserved names, so `AshOnetime.Resource`'s compile-time verifier rejects any protected
  action on that resource regardless of strategy or accept list (see the comment on
  `Xaas.Accounts.Token`'s `:revoke_token` action). This resource carries no such attribute, so
  it hosts the real `onetime`/`protect` block instead. `Xaas.Accounts.Token.EnforceSingleRevoke`
  claims a nonce here, keyed on the raw token string being revoked, before the real revocation
  record is written -- so the same token string can drive `:revoke_token` to completion at most
  once, even under client retry.
  """

  use Ash.Resource,
    otp_app: :kanban,
    domain: Xaas.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOnetime.Resource]

  postgres do
    table "token_revoke_nonces"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :claim do
      description "Claims the one-time revoke nonce for a raw token string. Real effect: " <>
                     "on second and later calls with the same token string, ash_onetime " <>
                     "rejects with :nonce_already_used before this changeset ever inserts."
      argument :token, :string, allow_nil?: false, sensitive?: true
    end
  end

  onetime do
    protect :claim do
      strategy :one_time_nonce
      scope [{:static, "revoke_token"}]
      key {:verified, :token, Xaas.Accounts.Token.RevokeVerifier}
      window max_age: {5, :minute}, clock_skew: {30, :second}
    end
  end

  attributes do
    uuid_primary_key :id
  end
end
