defmodule Xaas.Repo.Migrations.AddSpgIdentityToActuationEvidence do
  use Ecto.Migration

  def change do
    alter table(:actuation_intents) do
      add(:spg_graph_id, :text)
      add(:spg_graph_version, :text)
      add(:spg_node_id, :text)
      add(:spg_edge_id, :text)
    end

    alter table(:actuation_receipts) do
      add(:spg_graph_id, :text)
      add(:spg_graph_version, :text)
      add(:spg_node_id, :text)
      add(:spg_edge_id, :text)
    end
  end
end
