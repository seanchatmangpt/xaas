defmodule Xaas.Governance.Types.ProjectTier do
  @moduledoc """
  Real tier enum, values ported verbatim from platform-console's
  `ProjectTier` type (`platform-console/app/lib/backup-retention.ts`):
  `"starter" | "pro" | "enterprise"`.
  """
  use Ash.Type.Enum, values: [:starter, :pro, :enterprise]
end
