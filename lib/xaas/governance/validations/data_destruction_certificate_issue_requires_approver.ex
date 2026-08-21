defmodule Xaas.Governance.Validations.DataDestructionCertificateIssueRequiresApprover do
  @moduledoc """
  Real business rule for `Xaas.Governance.DataDestructionCertificateIssue`'s
  `:approve` action, matching platform-console's real maker-checker
  requirement on `POST /api/owner/data-destruction`
  (`data-destruction.certificate.issue` approval workflow): a distinct,
  second owner-role approver must be named, and they may not be the same
  actor who filed the certificate-issue request.
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
        {:error,
         field: :approved_by, message: "is required to approve a data destruction certificate issuance"}

      approved_by == requested_by ->
        {:error,
         field: :approved_by,
         message: "must be a second, distinct owner -- cannot approve their own request"}

      true ->
        :ok
    end
  end
end
