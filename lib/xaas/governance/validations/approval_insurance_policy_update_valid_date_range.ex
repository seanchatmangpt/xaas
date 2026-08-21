defmodule Xaas.Governance.Validations.ApprovalInsurancePolicyUpdateValidDateRange do
  @moduledoc """
  Real field-level validation, ported verbatim from platform-console's
  `PUT /api/owner/insurance-attestation` handler: `expiryDate` must be
  strictly after `effectiveDate`, and `coverageLimitUsd` must be a
  positive amount (`coverageLimitUsd <= 0` was rejected as a 400 there).
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    effective_date = Ash.Changeset.get_attribute(changeset, :effective_date)
    expiry_date = Ash.Changeset.get_attribute(changeset, :expiry_date)
    coverage_limit_usd = Ash.Changeset.get_attribute(changeset, :coverage_limit_usd)

    cond do
      not is_nil(coverage_limit_usd) and Decimal.compare(coverage_limit_usd, 0) != :gt ->
        {:error, field: :coverage_limit_usd, message: "must be greater than 0"}

      not is_nil(effective_date) and not is_nil(expiry_date) and
          Date.compare(expiry_date, effective_date) != :gt ->
        {:error, field: :expiry_date, message: "must be after effective_date"}

      true ->
        :ok
    end
  end
end
