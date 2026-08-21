defmodule Xaas.Governance.Validations.ApprovalEnvironmentPromoteRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Governance.ApprovalEnvironmentPromote`'s
  `:approve` action, matching platform-console's real maker-checker
  requirement on `POST /api/projects/[name]/promote` (via
  `requireApproval("environment.promote")`): a distinct, second owner-role
  approver must be named, and they may not be the same actor who requested
  the promotion.
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
        {:error, field: :approved_by, message: "is required to approve an environment promotion"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by, message: "must be a second, distinct owner -- cannot approve their own request"}

      true ->
        :ok
    end
  end
end
