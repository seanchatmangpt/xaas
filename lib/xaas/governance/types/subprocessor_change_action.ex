defmodule Xaas.Governance.Types.SubprocessorChangeAction do
  @moduledoc """
  Real change-action enum, ported verbatim from platform-console's
  `applySubprocessorChange` action union (`platform-console/app/lib/subprocessors.ts`):
  `"added" | "updated" | "removed"` -- POST /api/subprocessors requests "added",
  PUT /api/subprocessors/[id] requests "updated", DELETE requests "removed".
  """
  use Ash.Type.Enum, values: [:added, :updated, :removed]
end
