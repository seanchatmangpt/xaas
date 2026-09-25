defmodule Xaas.Governance.Types.LeResponseStatus do
  @moduledoc """
  Real response-status enum, values ported verbatim from
  platform-console's `RESPONSE_STATUSES` constant
  (`app/api/owner/le-requests/route.ts`):
  `"disclosed" | "narrowed" | "objected" | "rejected"`.
  """
  use Ash.Type.Enum, values: [:disclosed, :narrowed, :objected, :rejected]
end
