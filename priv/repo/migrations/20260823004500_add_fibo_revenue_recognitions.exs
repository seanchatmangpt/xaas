defmodule Xaas.Repo.Migrations.AddFiboRevenueRecognitions do
  use Ecto.Migration

  def change do
    create table(:billing_revenue_recognitions, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :org_id, :text, null: false
      add :source_key, :text, null: false
      add :source_label, :text, null: false
      add :source_iri, :text, null: false
      add :economic_family, :text, null: false
      add :accounting_classification, :text, null: false
      add :recognition_basis, :text, null: false
      add :amount, :decimal, null: false
      add :currency, :text, null: false
      add :contract_ref, :text
      add :counterparty_ref, :text
      add :external_ref, :text
      add :evidence, :map, null: false, default: %{}
      add :period_start, :utc_datetime
      add :period_end, :utc_datetime
      add :recognized_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:billing_revenue_recognitions, [:org_id, :recognized_at])
    create index(:billing_revenue_recognitions, [:source_iri])
    create index(:billing_revenue_recognitions, [:accounting_classification])
  end
end
