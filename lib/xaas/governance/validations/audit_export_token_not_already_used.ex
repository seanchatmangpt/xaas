defmodule Xaas.Governance.Validations.AuditExportTokenNotAlreadyUsed do
  @moduledoc """
  Idempotency guard for `Xaas.Governance.AuditExportToken`'s `:use`
  action (lane W935, SPEC-16) -- rejects a second use of a token whose
  `used_at` is already stamped, mirroring the landed
  `Xaas.Governance.Validations.AuditExportTokenNotAlreadyRevoked`
  guard idiom (same file family, W740 class) cited by SPEC-16.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_data(changeset, :used_at) do
      nil -> :ok
      _ -> {:error, field: :used_at, message: "token is already used"}
    end
  end
end
