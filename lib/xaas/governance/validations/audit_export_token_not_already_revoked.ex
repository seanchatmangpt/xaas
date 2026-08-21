defmodule Xaas.Governance.Validations.AuditExportTokenNotAlreadyRevoked do
  @moduledoc """
  Idempotency guard for `Xaas.Governance.AuditExportToken`'s `:revoke`
  action -- rejects revoking a token whose `revoked_at` is already set,
  same shape as `ApprovalDrFailoverRequiresApprover`.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_data(changeset, :revoked_at) do
      nil -> :ok
      _ -> {:error, field: :revoked_at, message: "token is already revoked"}
    end
  end
end
