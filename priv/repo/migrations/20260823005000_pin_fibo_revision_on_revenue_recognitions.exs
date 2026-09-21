defmodule Xaas.Repo.Migrations.PinFiboRevisionOnRevenueRecognitions do
  use Ecto.Migration

  @fibo_revision "119fa8c091aa4beece7d22aefa6fe138021a4355"

  def up do
    alter table(:billing_revenue_recognitions) do
      add :source_revision, :text
    end

    execute(
      "UPDATE billing_revenue_recognitions SET source_revision = '#{@fibo_revision}' WHERE source_revision IS NULL"
    )

    execute(
      "ALTER TABLE billing_revenue_recognitions ALTER COLUMN source_revision SET NOT NULL"
    )

    create index(:billing_revenue_recognitions, [:source_iri, :source_revision])
  end

  def down do
    drop index(:billing_revenue_recognitions, [:source_iri, :source_revision])

    alter table(:billing_revenue_recognitions) do
      remove :source_revision
    end
  end
end
