defmodule Xaas.Governance.Types.ExportSubscriptionCadence do
  @moduledoc """
  Real cadence enum, values ported verbatim from platform-console's
  `isExportCadence` guard (`platform-console/app/lib/s3-export-subscription.ts`):
  `"daily" | "weekly"`.
  """
  use Ash.Type.Enum, values: [:daily, :weekly]
end
