defmodule Xaas.Governance.Validations.ApprovalSourceEscrowSnapshotRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Governance.ApprovalSourceEscrowSnapshot`'s
  `:approve` action, matching platform-console's real maker-checker
  requirement on `POST /api/compliance/source-escrow`
  (`source-escrow.snapshot` approval kind): a distinct, second owner-role
  approver must sign off before the collected manifest is ever signed and
  persisted, and they may not be the same actor who requested the snapshot.
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
        {:error, field: :approved_by, message: "is required to approve a source-escrow snapshot"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by,
         message: "must be a second, distinct owner -- cannot approve their own request"}

      true ->
        :ok
    end
  end
end
