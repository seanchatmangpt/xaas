defmodule Xaas.Platform.Validations.RouteSecretsRequiresApprover do
  @moduledoc """
  Real maker-checker rule for `Xaas.Platform.RouteSecrets`' `:approve`
  action (W792): `approved_by` must be present and must name a second,
  distinct actor -- never the requester themself. Mirrors the Governance
  house pattern
  (`Xaas.Governance.Validations.ApprovalBackupRetentionChangeRequiresApprover`).
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    approved_by = Ash.Changeset.get_attribute(changeset, :approved_by)
    requested_by = Ash.Changeset.get_attribute(changeset, :requested_by)

    cond do
      is_nil(approved_by) or approved_by == "" ->
        {:error, field: :approved_by, message: "is required to approve a secret"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by,
         message: "must be a second, distinct actor -- cannot approve their own request"}

      true ->
        :ok
    end
  end
end
