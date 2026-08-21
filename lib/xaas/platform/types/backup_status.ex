defmodule Xaas.Platform.Types.BackupStatus do
  @moduledoc """
  Real status enum, ported verbatim from platform-console's `BackupStatus`
  type (`platform-console/app/lib/backup-retention.ts`):
  `"pending" | "running" | "completed" | "failed" | "expired"`.
  """
  use Ash.Type.Enum, values: [:pending, :running, :completed, :failed, :expired]
end
