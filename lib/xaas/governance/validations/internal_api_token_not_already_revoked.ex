defmodule Xaas.Governance.Validations.InternalApiTokenNotAlreadyRevoked do
  @moduledoc """
  Idempotency guard for `Xaas.Governance.InternalApiToken`'s `:revoke`
  action -- rejects revoking a token whose `revoked_at` is already set.
  Same shape as `Xaas.Governance.Validations.
  AuditExportTokenNotAlreadyRevoked` (a real, generic-over-`revoked_at`
  check; kept as its own module rather than reused directly so this
  resource's validation is discoverable and documented on its own terms,
  matching this codebase's established one-validation-module-per-resource
  convention).
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
