defmodule Xaas.Repo.Migrations.AddCastleRunIdToIncidents do
  @moduledoc """
  W970b (closing W793 GAP(NO_CROSS_REFERENCE)): the architecture's implied
  incident↔castle link, which W793 observed absent at the resource layer on
  both sides, becomes a real nullable reference from an incident to the
  route-castle run ledger row it was opened about (or that was actuated in
  response). Nullable: most incidents have no castle run; the ledger side
  stays read-only generated projection and is deliberately untouched.
  """
  use Ecto.Migration

  def change do
    alter table(:incidents) do
      add :castle_run_id, :uuid
    end

    create index(:incidents, [:castle_run_id])
  end
end
