defmodule Xaas.Vault do
  @moduledoc """
  Cloak vault used by `AshCloak` to encrypt/decrypt sensitive attributes
  (see `Xaas.Accounts.Token`'s `cloak` block).

  Follows the standard `cloak_ex` setup: a keyring of one or more ciphers,
  the `:default` one used for new encryption, all others kept around only
  so already-encrypted data can still be decrypted after a key rotation.

  DEV-ONLY PLACEHOLDER KEY: the key baked in below
  (`CLOAK_KEY`, base64-decoded) is a fixed, publicly-visible placeholder
  committed to this repo. It is fine for local dev/test where the
  encrypted column round-trips inside a throwaway database, but it must
  NOT be used in any shared or production environment. Set the
  `CLOAK_KEY` env var (32 raw bytes, base64-encoded — e.g.
  `:crypto.strong_rand_bytes(32) |> Base.encode64()`) to override it.
  """
  use Cloak.Vault, otp_app: :kanban

  @impl GenServer
  def init(config) do
    key =
      System.get_env("CLOAK_KEY", "4T4/f5PYK0d489Do8sNU8VNJHKD/1XVOLXyzHUlIkQY=")
      |> Base.decode64!()

    config =
      Keyword.put(config, :ciphers,
        default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: key, iv_length: 12}
      )

    {:ok, config}
  end
end
