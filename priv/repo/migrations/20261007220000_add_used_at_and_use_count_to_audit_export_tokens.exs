defmodule Xaas.Repo.Migrations.AddUsedAtAndUseCountToAuditExportTokens do
  use Ecto.Migration

  def change do
    alter table(:audit_export_tokens) do
      add :used_at, :utc_datetime_usec
      add :use_count, :integer, default: 0, null: false
    end
  end
end
