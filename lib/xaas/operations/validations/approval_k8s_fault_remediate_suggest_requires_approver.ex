defmodule Xaas.Operations.Validations.ApprovalK8sFaultRemediateSuggestRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Operations.ApprovalK8sFaultRemediateSuggest`'s `:approve`
  action: an approval must name a real approver, and a requester may not
  approve their own k8s fault remediation suggestion request (maker-checker -- same shape as
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
        {:error, field: :approved_by, message: "is required to approve a k8s fault remediation suggestion"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by, message: "cannot approve their own k8s fault remediation suggestion request"}

      true ->
        :ok
    end
  end
end
