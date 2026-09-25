defmodule Xaas.Governance.Types.LeRequestType do
  @moduledoc """
  Real request-type enum, values ported verbatim from platform-console's
  `LeRequestType` (`platform-console/app/lib/le-requests.ts`, also mirrored
  as `VALID_TYPES` in `app/api/internal/le-requests/route.ts`):
  `"subpoena" | "warrant" | "court_order" | "national_security_letter" |
  "other"`.
  """
  use Ash.Type.Enum,
    values: [:subpoena, :warrant, :court_order, :national_security_letter, :other]
end
