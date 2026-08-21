defmodule Xaas.Governance.Validations.ApprovalBreakGlassJustificationReviewRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Governance.ApprovalBreakGlassJustificationReview`'s
  `:approve` action, matching platform-console's real compensating-control
  requirement (the two-person-integrity loop `lib/break-glass.ts`'s
  `fileBreakGlassJustification` opens): a distinct, second platform-admin
  reviewer must sign off on the post-hoc justification, and they may not be
  the same actor who filed it.
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
        {:error, field: :approved_by, message: "is required to approve a break-glass justification review"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by,
         message: "must be a second, distinct platform admin -- cannot review their own justification"}

      true ->
        :ok
    end
  end
end
