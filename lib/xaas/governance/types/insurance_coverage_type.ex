defmodule Xaas.Governance.Types.InsuranceCoverageType do
  @moduledoc """
  Real coverage-type enum, values ported verbatim from platform-console's
  `INSURANCE_COVERAGE_TYPES` (`platform-console/app/lib/insurance-attestation.ts`):
  `"cyber" | "errors_omissions" | "general_liability"`.
  """
  use Ash.Type.Enum, values: [:cyber, :errors_omissions, :general_liability]
end
