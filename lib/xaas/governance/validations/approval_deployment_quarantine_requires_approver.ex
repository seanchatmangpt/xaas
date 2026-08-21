defmodule Xaas.Governance.Validations.ApprovalDeploymentQuarantineRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Governance.ApprovalDeploymentQuarantine`'s
  `:approve` action, matching the maker-checker pattern used by every
  other ported approval resource in this domain (e.g.
  `ApprovalDrFailoverRequiresApprover`): a distinct, second approver must
  be named, and they may not be the same actor who requested the
  quarantine.
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
        {:error, field: :approved_by, message: "is required to approve a deployment quarantine"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by,
         message: "must be a second, distinct approver -- cannot approve their own request"}

      true ->
        :ok
    end
  end
end
