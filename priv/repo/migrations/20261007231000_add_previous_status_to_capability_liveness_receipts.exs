defmodule Xaas.Repo.Migrations.AddPreviousStatusToCapabilityLivenessReceipts do
  @moduledoc """
  W968c / SPEC-14 (W750-G2): `detect/1` was blind to upsert-overwritten
  regressions because the identity upsert destroyed prior-ALIVE history.
  `previous_status` preserves the immediately-prior observed status at
  re-ingest time so the regression detector can see an in-place
  ALIVE->non-ALIVE flip on the same capability+subject row.
  """

  use Ecto.Migration

  def change do
    alter table(:capability_liveness_receipts) do
      add :previous_status, :text
    end
  end
end
