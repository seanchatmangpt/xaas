defmodule Xaas.Governance.Validations.ApprovalBackupRetentionChangeRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Governance.ApprovalBackupRetentionChange`'s
  `:approve` action, matching the real maker-checker requirement enforced
  in platform-console's `PUT /api/orgs/[id]/backup-policy` (a retention
  change is a compliance-evidence-affecting decision -- shortening the
  window can destroy a customer's own regulatory evidence trail): a
  distinct, second owner-role approver must be named, and they may not be
  the same actor who requested the change.
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
        {:error,
         field: :approved_by, message: "is required to approve a backup-retention change"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by,
         message: "must be a second, distinct owner -- cannot approve their own request"}

      true ->
        :ok
    end
  end
end
