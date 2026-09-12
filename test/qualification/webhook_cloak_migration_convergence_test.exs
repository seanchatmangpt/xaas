defmodule Xaas.WebhookCloakMigrationConvergenceTest do
  use ExUnit.Case, async: true

  @owner Path.expand("../../priv/repo/migrations/20260821031500_fix_webhook_secret_encryption_column.exs", __DIR__)
  @later Path.expand("../../priv/repo/migrations/20260821055848_resolve_pending_backlog_20260821.exs", __DIR__)

  test "webhook cloak storage has exactly one idempotent migration owner" do
    owner = File.read!(@owner)
    later = File.read!(@later)

    assert owner =~ "ADD COLUMN IF NOT EXISTS encrypted_secret"
    assert owner =~ "DROP COLUMN IF EXISTS secret"

    refute later =~ "alter table(:platform_webhooks)"
    refute later =~ "add :encrypted_secret"
    refute later =~ "remove :secret"
  end
end
