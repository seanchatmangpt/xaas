defmodule Xaas.Governance.Types.SubprocessorCategory do
  @moduledoc """
  Real category enum, values ported verbatim from platform-console's
  `SubprocessorCategory` type (`platform-console/app/lib/subprocessors.ts`):
  `"cloud-infrastructure" | "third-party-service"`.
  """
  use Ash.Type.Enum, values: [:"cloud-infrastructure", :"third-party-service"]
end
