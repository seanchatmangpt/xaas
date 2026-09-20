defmodule Xaas.Repo.Migrations.AddSemanticWorkIdentityToUltracodeRuns do
  use Ecto.Migration

  def change do
    alter table(:ultracode_runs) do
      add :work_order_iri, :text
      add :checkpoint_iri, :text
      add :graph_digest, :string, size: 128
      add :repository_identity, :text
      add :execution_repo_alias, :string, size: 128
      add :execution_policy, :text
      add :dependency_evidence, :map, null: false, default: %{}
      add :base_sha, :string, size: 40
    end

    create index(:ultracode_runs, [:work_order_iri])
    create index(:ultracode_runs, [:checkpoint_iri])
    create index(:ultracode_runs, [:graph_digest])
    create index(:ultracode_runs, [:repository_identity])
  end
end
