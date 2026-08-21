defmodule Xaas.Governance.Validations.ApprovalLegalHoldReleaseRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Governance.ApprovalLegalHoldRelease`'s
  `:approve` action, matching platform-console's real maker-checker
  requirement in `PUT /api/owner/legal-hold` (`requireLegalHoldReleaseApproval`,
  the same `legal-hold.release` workflow `dsar.erasure`/`dr.failover` use): a
  distinct, second owner approver must be named, and they may not be the
  same actor who requested the release -- one owner's own say-so that
  litigation has concluded is never sufficient by itself.
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
        {:error, field: :approved_by, message: "is required to approve a legal hold release"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by, message: "must be a second, distinct owner -- cannot approve their own request"}

      true ->
        :ok
    end
  end
end
