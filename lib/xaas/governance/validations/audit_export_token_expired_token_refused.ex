defmodule Xaas.Governance.Validations.AuditExportTokenExpiredTokenRefused do
  @moduledoc """
  Expiry guard for `Xaas.Governance.AuditExportToken`'s `:use` action
  (lane W935, SPEC-17): refuses use of a token past its `expires_at`,
  closing the disclosed W765 gap "reuse-after-expiry is not refused by
  any action -- only `active?` flips". Typed on field `:expires_at`
  exactly as the SPEC-17 court demands (`Ash.Error.Invalid`, field
  `:expires_at`).
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    expires_at = Ash.Changeset.get_data(changeset, :expires_at)

    case expires_at do
      nil -> :ok
      _ -> if DateTime.compare(expires_at, DateTime.utc_now()) == :gt, do: :ok, else: {:error, field: :expires_at, message: "token is expired"}
    end
  end
end
