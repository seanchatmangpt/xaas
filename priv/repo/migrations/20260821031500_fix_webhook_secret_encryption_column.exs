defmodule Xaas.Repo.Migrations.FixWebhookSecretEncryptionColumn do
  @moduledoc """
  Real fix for a real regression: `20260821030000_cloak_webhook_secret.exs`
  reasoned (by analogy to `tokens.extra_data`) that `AshCloak.cloak
  attributes [:secret]` on `Xaas.Platform.Webhook` needs no DDL because
  cloak "encrypts in place" without a column-name change.

  That analogy does not hold. Read
  `deps/ash_cloak/lib/ash_cloak/transformers/set_up_encryption.ex`
  (`AshCloak.Transformers.SetupEncryption.transform/1`): for every cloaked
  attribute `name`, the transformer unconditionally
  `remove_entity`-s the plain attribute and `add_attribute`-s a new,
  real `:"encrypted_\#{name}"` `:binary` column, then adds a `name`
  calculation that decrypts `encrypted_\#{name}` back into `name` at read
  time. There is no configuration knob in this AshCloak version to keep
  the original column name -- the `encrypted_` prefix and the `:binary`
  type are load-bearing, not cosmetic. So `Xaas.Platform.Webhook`'s Ash
  resource genuinely queries `platform_webhooks.encrypted_secret`
  (confirmed by the real Postgrex `42703 undefined_column` failures this
  migration fixes), while the actual table still only has the old
  `secret :text` column from
  `20260821023049_webhooks_and_stress_bench.exs`.

  (Whether `Xaas.Accounts.Token.extra_data` has the same latent bug is a
  separate, pre-existing question this migration does not touch --
  no test in this sweep exercises that read path, so it is out of scope
  here.)

  Real fix: add the real `encrypted_secret :binary` column AshCloak
  actually reads/writes, and drop the now-dead plaintext `secret` column.
  Safe as a real destructive drop here specifically because this webhook
  feature shipped this same session with no production traffic yet (see
  `Xaas.Platform.Webhook`'s moduledoc) -- there is no real ciphertext or
  plaintext data in `secret` anywhere to lose.
  """

  use Ecto.Migration

  def up do
    alter table(:platform_webhooks) do
      add :encrypted_secret, :binary, null: false, default: fragment("''::bytea")
      remove :secret
    end

    alter table(:platform_webhooks) do
      modify :encrypted_secret, :binary, null: false, default: nil
    end
  end

  def down do
    alter table(:platform_webhooks) do
      add :secret, :text, null: false, default: ""
      remove :encrypted_secret
    end

    alter table(:platform_webhooks) do
      modify :secret, :text, null: false, default: nil
    end
  end
end
