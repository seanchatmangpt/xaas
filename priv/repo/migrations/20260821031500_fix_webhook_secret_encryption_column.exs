defmodule Xaas.Repo.Migrations.FixWebhookSecretEncryptionColumn do
  @moduledoc """
  Converges the webhook secret storage required by AshCloak.

  AshCloak materializes a real `encrypted_secret` binary column. Historical
  repository paths can reach this migration with either the original
  `secret` column still present or an already-converged schema where it is
  absent. The migration therefore admits both observed predecessor shapes
  and converges them to one result instead of assuming ambient history.
  """

  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE platform_webhooks
      ADD COLUMN IF NOT EXISTS encrypted_secret bytea NOT NULL DEFAULT ''::bytea
    """)

    execute("ALTER TABLE platform_webhooks DROP COLUMN IF EXISTS secret")
    execute("ALTER TABLE platform_webhooks ALTER COLUMN encrypted_secret DROP DEFAULT")
  end

  def down do
    execute("""
    ALTER TABLE platform_webhooks
      ADD COLUMN IF NOT EXISTS secret text NOT NULL DEFAULT ''
    """)

    execute("ALTER TABLE platform_webhooks DROP COLUMN IF EXISTS encrypted_secret")
    execute("ALTER TABLE platform_webhooks ALTER COLUMN secret DROP DEFAULT")
  end
end
