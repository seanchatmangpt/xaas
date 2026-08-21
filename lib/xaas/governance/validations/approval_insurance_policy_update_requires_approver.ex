defmodule Xaas.Governance.Validations.ApprovalInsurancePolicyUpdateRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Governance.ApprovalInsurancePolicyUpdate`'s
  `:approve` action, matching platform-console's real
  `insurance.policy.update` maker-checker requirement (`PUT
  /api/owner/insurance-attestation`): a distinct, second owner approver must
  be named, and they may not be the same actor who requested the policy
  update.
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
        {:error, field: :approved_by, message: "is required to approve an insurance policy update"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by, message: "must be a second, distinct owner -- cannot approve their own request"}

      true ->
        :ok
    end
  end
end
