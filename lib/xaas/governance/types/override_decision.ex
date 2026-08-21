defmodule Xaas.Governance.Types.OverrideDecision do
  @moduledoc """
  Real decision enum, values ported verbatim from platform-console's
  `OVERRIDE_DECISIONS` in
  `app/api/owner/[orgId]/denied-party-screening/route.ts`:
  `"cleared_to_proceed" | "confirmed_blocked"`.
  """
  use Ash.Type.Enum, values: [:cleared_to_proceed, :confirmed_blocked]
end
