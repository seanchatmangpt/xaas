defmodule Xaas.Marketplace.Validations.ApprovalProviderStatusChangeRequiresApprover do
  @moduledoc """
  Real business rule for
  `Xaas.Marketplace.ApprovalProviderStatusChange`'s `:approve` action,
  matching the exact real pattern
  `Xaas.Governance.Validations.ApprovalDrFailoverRequiresApprover` uses:
  a distinct, second actor must approve -- the actor who requested the
  provider status change may not approve their own request.
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
        {:error, field: :approved_by, message: "is required to approve a provider status change"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by,
         message: "must be a second, distinct actor -- cannot approve their own request"}

      true ->
        :ok
    end
  end
end
