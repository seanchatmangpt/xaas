defmodule Xaas.Repo.Migrations.CloakWebhookSecret do
  @moduledoc """
  No-op schema migration, kept as a real, disclosed record of the
  column-naming decision for wiring `AshCloak` onto
  `Xaas.Platform.Webhook.secret` (see that resource's `cloak do ... end`
  block).

  Real decision: no column rename, no new column. `platform_webhooks.secret`
  is already `:text` (unbounded) per
  `20260821023049_webhooks_and_stress_bench.exs` -- AshCloak encrypts the
  `:secret` attribute transparently at the Ash `Ash.Type` level (ciphertext
  is base64-encoded and written into the same `:string`/`:text` column); it
  does not require a storage-type or column-name change to hold ciphertext
  instead of plaintext.

  This mirrors the real, already-established precedent in this repo for
  `Xaas.Accounts.Token.extra_data`: codegen repeatedly proposed renaming
  `tokens.extra_data` -> `tokens.encrypted_extra_data` after `AshCloak` was
  wired onto that attribute, and every prior migration in this session
  (`20260820235809_add_backup_retention_change_columns.exs` through
  `20260821023049_webhooks_and_stress_bench.exs`) deliberately excluded that
  rename as destructive and unnecessary -- `tokens.extra_data` is still
  named `extra_data` in the database today, encrypted in place. Applying
  `AshCloak` to `Webhook.secret` follows that same real precedent: the
  column stays named `secret`, still `:text`, now holding ciphertext.

  down/0 is likewise a no-op for the same reason.
  """

  use Ecto.Migration

  def up do
    :ok
  end

  def down do
    :ok
  end
end
