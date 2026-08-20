defmodule Xaas.Billing.Validations.ApprovalPricingOverrideRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Billing.ApprovalPricingOverride`'s `:approve`
  action: an approval must name a real approver, and a requester may not
  approve their own pricing-override request.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def validate(changeset, _opts, _context) do
    approved_by = Ash.Changeset.get_attribute(changeset, :approved_by)
    requested_by = Ash.Changeset.get_attribute(changeset, :requested_by)

    cond do
      is_nil(approved_by) or approved_by == "" ->
        {:error, field: :approved_by, message: "is required to approve a pricing override"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by, message: "cannot approve their own pricing override request"}

      true ->
        :ok
    end
  end
end
