defmodule Xaas.Billing.Validations.ApprovalSlaCreditApplyRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Billing.ApprovalSlaCreditApply`'s `:approve`
  action: an approval must name a real approver, and a requester may not
  approve their own SLA credit application request (maker-checker -- same shape as
  `Xaas.Billing.Validations.ApprovalPricingOverrideRequiresApprover` and
  every other `*RequiresApprover` validation in this codebase).
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
        {:error, field: :approved_by, message: "is required to approve a SLA credit application"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by, message: "cannot approve their own SLA credit application request"}

      true ->
        :ok
    end
  end
end
