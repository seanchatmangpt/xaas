defmodule Xaas.Repo.Migrations.AddSemanticWorkIdentityToUltracodeRuns do
  use Ecto.Migration

  def change do
    alter table(:ultracode_runs) do
      add :checkpoint_iri, :text
      add :graph_digest, :string, size: 128
      add :base_sha, :string, size: 40
    end

    create index(:ultracode_runs, [:checkpoint_iri])
    create index(:ultracode_runs, [:graph_digest])
  end
end
