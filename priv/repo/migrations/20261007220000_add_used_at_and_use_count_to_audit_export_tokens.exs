defmodule Xaas.Repo.Migrations.AddUsedAtAndUseCountToAuditExportTokens do
  use Ecto.Migration

  def up do
    alter table(:audit_export_tokens) do
      # Replay-safe (W971b): guard each column against direct-DDL replay.
      add_if_not_exists :used_at, :utc_datetime_usec
      add_if_not_exists :use_count, :integer, default: 0, null: false
    end
  end

  def down do
    if column_exists?("audit_export_tokens", "use_count") do
      alter table(:audit_export_tokens) do
        remove :use_count
      end
    end

    if column_exists?("audit_export_tokens", "used_at") do
      alter table(:audit_export_tokens) do
        remove :used_at
      end
    end
  end

  defp column_exists?(table, column) do
    repo().query!(
      "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = $1 AND column_name = $2)",
      [table, column]
    ).rows |> List.flatten() |> hd()
  end
end
