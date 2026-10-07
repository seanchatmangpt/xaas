defmodule Xaas.Billing.Validations.ApprovalPricingOverrideRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Billing.ApprovalPricingOverride`'s `:approve`
  action: an approval must name a real approver, and a requester may not
  approve their own pricing-override request.
  """
  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute

  @impl true
  def init(opts) do
    {:ok, opts}
  end


  # SPEC-08 / W729-GAP-4 (lane W984cc): atomic/3 so the :approve action can
  # run atomically after require_atomic?(false) was dropped. Same rule as
  # validate/3, re-derived server-side in SQL: refuse when the new
  # approved_by is absent or equals the persisted requested_by
  # (requested_by never changes on :approve).
  @impl true
  def atomic(_changeset, _opts, _context) do
    {:atomic, [:approved_by],
     expr(
       is_nil(^atomic_ref(:approved_by)) or ^atomic_ref(:approved_by) == "" or
         ^atomic_ref(:approved_by) == requested_by
     ),
     expr(
       error(^InvalidAttribute, %{
         field: :approved_by,
         value: ^atomic_ref(:approved_by),
         message: "is required and must differ from requested_by"
       })
     )}
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
