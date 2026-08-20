defmodule Xaas.Accounts.Token.RevokeVerifier do
  @moduledoc """
  `AshOnetime.Verifier` used to key the one-time-nonce protection on
  `Xaas.Accounts.Token`'s `:revoke_token` action.

  The raw token material a caller supplies for revocation is untrusted action input; it
  cannot assert its own verification. This module derives a trusted local fact (the HMAC
  digest of the raw token under a same-service key) that `ash_onetime` uses as the nonce's
  spend key, so the *same* token string can revoke at most once even under retries, while
  distinct token strings never collide.
  """

  @behaviour AshOnetime.Verifier

  alias AshOnetime.Verified

  @impl AshOnetime.Verifier
  def verify(raw_token, _context) when is_binary(raw_token) and raw_token != "" do
    {:ok,
     %Verified{
       key: :crypto.mac(:hmac, :sha256, verification_key(), raw_token),
       issued_at: DateTime.utc_now(),
       verifier_id: "xaas.accounts.token.revoke_verifier/1"
     }}
  end

  def verify(_raw_token, _context), do: {:error, :invalid_token}

  @impl AshOnetime.Verifier
  def algorithm, do: :hmac_sha256

  @impl AshOnetime.Verifier
  def trust_model, do: :same_service

  defp verification_key do
    Application.fetch_env!(:kanban, Xaas.Accounts.Token)[:onetime_revoke_key] ||
      raise "missing :onetime_revoke_key config for Xaas.Accounts.Token"
  end
end
