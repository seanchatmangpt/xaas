defmodule Xaas.Governance.Types.ChangeOfControlEventType do
  @moduledoc """
  Real event-type enum, values ported verbatim from platform-console's
  `ChangeOfControlEventType` (`platform-console/app/lib/change-of-control-
  notifications.ts`) and its route-level `EVENT_TYPES` guard
  (`platform-console/app/app/api/owner/change-of-control/route.ts`):
  `"acquisition" | "merger" | "ownership_change"`.
  """
  use Ash.Type.Enum, values: [:acquisition, :merger, :ownership_change]
end
