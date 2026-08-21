defmodule Xaas.Governance.Validations.ApprovalChangeOfControlNotifyRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Governance.ApprovalChangeOfControlNotify`'s
  `:approve` action, matching platform-console's real maker-checker
  requirement on `PUT /api/owner/change-of-control` (the
  `change-of-control.notify` `requireApproval` workflow): a distinct,
  second owner-role approver must be named, and they may not be the same
  actor who filed the notification request.
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
        {:error, field: :approved_by, message: "is required to approve a change-of-control notification"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by, message: "must be a second, distinct owner -- cannot approve their own request"}

      true ->
        :ok
    end
  end
end
