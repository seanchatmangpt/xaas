defmodule Xaas.Governance.Changes.GenerateInternalApiToken do
  @moduledoc """
  Real token minting for `Xaas.Governance.InternalApiToken`'s `:issue`
  action -- same shape as `Xaas.Governance.Changes.
  GenerateAuditExportToken`: generate a raw bearer token, hash it before
  persistence, never store or re-derive the raw value.

  Real, deliberate difference from that module: the raw token is attached
  to the *result* via `Ash.Resource.put_metadata/3` inside an
  `Ash.Changeset.after_action/2` callback, not `Ash.Changeset.put_context/2`
  on the changeset. Changeset context is never copied onto the record
  `Ash.create/2` returns, so a consumer reading `changeset.context` back
  off the result would always get `nil` -- confirmed by reading
  `AshAuthentication.GenerateTokenChange` (`deps/ash_authentication/lib/
  ash_authentication/generate_token_change.ex`, real-read in full), the
  exact mechanism this codebase's own `Xaas.Accounts.User` sign-in actions
  already use to hand a real JWT back to a caller without persisting it.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    prefix = Xaas.Governance.InternalApiTokenAuth.prefix()
    display_len = Xaas.Governance.InternalApiTokenAuth.display_prefix_len()

    raw_token = prefix <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))
    token_hash = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)
    token_prefix = String.slice(raw_token, 0, display_len)

    changeset
    |> Ash.Changeset.force_change_attribute(:token_hash, token_hash)
    |> Ash.Changeset.force_change_attribute(:token_prefix, token_prefix)
    |> Ash.Changeset.after_action(fn _changeset, result ->
      {:ok, Ash.Resource.put_metadata(result, :raw_token, raw_token)}
    end)
  end
end
