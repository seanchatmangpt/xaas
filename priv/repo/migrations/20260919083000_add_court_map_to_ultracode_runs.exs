defmodule Xaas.Repo.Migrations.AddCourtMapToUltracodeRuns do
  use Ecto.Migration

  # The fabric court-receipt contract (`Xaas.Ultracode.CourtReceipt`):
  # work-order-minted acceptance/falsifier/court IRIs mapped to the one
  # machine-checkable predicate each. Fabric-owned Run state, persisted at
  # materialization, read at close time -- never worker-supplied per call.
  def change do
    alter table(:ultracode_runs) do
      add :court_map, :map
    end
  end
end
