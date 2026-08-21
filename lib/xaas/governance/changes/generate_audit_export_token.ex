defmodule Xaas.Governance.Changes.GenerateAuditExportToken do
  @moduledoc """
  Real token minting for `Xaas.Governance.AuditExportToken`'s `:issue`
  action, matching platform-console's real "Storage"/"Issuance" discipline:
  generate a raw bearer token, hash it before persistence, and never store
  or re-derive the raw value. The raw token is put into the changeset's
  context so the caller can read it off the result exactly once.
  """
  use Ash.Resource.Change

  @prefix "aet_live_"
  @display_prefix_len 12

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    raw_token = @prefix <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))
    token_hash = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)
    token_prefix = String.slice(raw_token, 0, @display_prefix_len)

    changeset
    |> Ash.Changeset.force_change_attribute(:token_hash, token_hash)
    |> Ash.Changeset.force_change_attribute(:token_prefix, token_prefix)
    |> Ash.Changeset.put_context(:raw_token, raw_token)
  end
end
