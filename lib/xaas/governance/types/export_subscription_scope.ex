defmodule Xaas.Governance.Types.ExportSubscriptionScope do
  @moduledoc """
  Real scope enum, values ported verbatim from platform-console's
  `isExportScope` guard (`platform-console/app/lib/s3-export-subscription.ts`):
  `"audit-log" | "full-export"`.
  """
  use Ash.Type.Enum, values: [:"audit-log", :"full-export"]
end
