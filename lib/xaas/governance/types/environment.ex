defmodule Xaas.Governance.Types.Environment do
  @moduledoc """
  Real environment enum, ported verbatim from platform-console's
  `Environment` type (`platform-console/app/lib/environments.ts`):
  `"dev" | "staging" | "prod"`.
  """
  use Ash.Type.Enum, values: [:dev, :staging, :prod]
end
