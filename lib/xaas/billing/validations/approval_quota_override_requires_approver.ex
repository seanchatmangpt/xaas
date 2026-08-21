defmodule Xaas.Billing.Validations.ApprovalQuotaOverrideRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Billing.ApprovalQuotaOverride`'s `:approve`
  action: an approval must name a real approver, and a requester may not
  approve their own quota override request (maker-checker -- same shape as
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
        {:error, field: :approved_by, message: "is required to approve a quota override"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by, message: "cannot approve their own quota override request"}

      true ->
        :ok
    end
  end
end
