defmodule Xaas.VaultEnvGuardTest do
  @moduledoc """
  Lane W349 — _CLOSURE_PLAN.md §1 row 5: pins the `Xaas.Vault` `CLOAK_KEY`
  env-override contract (Chicago-style: real vault process, real
  encrypt/decrypt round-trips, real state assertions; no mocks).

  Contract under test (`lib/xaas/vault.html.ex` docs say): `init/1` reads
  `System.get_env("CLOAK_KEY", <committed placeholder>)`. When `CLOAK_KEY`
  IS set, the real value is the default cipher key; when unset, the
  committed placeholder is the fallback. No runtime prod guard exists.
  """

  use ExUnit.Case, async: false

  alias Xaas.Vault

  @placeholder_key Base.decode64!("4T4/f5PYK0d489Do8sNU8VNJHKD/1XVOLXyzHUlIkQY=")
  @real_key :crypto.strong_rand_bytes(32)
  @plaintext "w349-env-override-guard"

  setup do
    # Locate the app supervisor that owns the app-booted Xaas.Vault child so
    # we can terminate it WITHOUT triggering an automatic restart, then
    # restore it in on_exit.
    supervisor = find_vault_supervisor()
    assert supervisor != nil, "app-booted Xaas.Vault must be running"

    on_exit(fn ->
      System.delete_env("CLOAK_KEY")

      # Restore the app-owned vault after the ExUnit-managed copy is gone.
      if is_nil(Process.whereis(Vault)) do
        {:ok, _} = Supervisor.restart_child(supervisor, Vault)
      end
    end)

    # Terminate the app child (no auto-restart), wait for the name to clear.
    :ok = Supervisor.terminate_child(supervisor, Vault)
    wait_until(fn -> Process.whereis(Vault) == nil end)

    :ok
  end

  test "CLOAK_KEY set: the real value is used as the default cipher key" do
    System.put_env("CLOAK_KEY", Base.encode64(@real_key))

    start_supervised!(Vault)

    {:ok, ciphertext} = Vault.encrypt(@plaintext)
    assert is_binary(ciphertext)
    # Real round-trip under the env-provided key.
    assert Vault.decrypt(ciphertext) == {:ok, @plaintext}

    # Pin that the env key -- not the placeholder -- produced this data:
    # the vault's ciphertext decrypts ONLY under the env key and fails
    # under the committed placeholder key (GCM auth-tag mismatch).
    assert try_decrypt_with_key(@real_key, ciphertext) == {:ok, @plaintext}
    assert try_decrypt_with_key(@placeholder_key, ciphertext) in [:error, {:ok, :error}]
  end

  test "CLOAK_KEY unset: committed placeholder is the fallback key" do
    System.delete_env("CLOAK_KEY")

    start_supervised!(Vault)

    {:ok, ciphertext} = Vault.encrypt(@plaintext)
    assert Vault.decrypt(ciphertext) == {:ok, @plaintext}

    # The fallback key IS the committed placeholder: the vault's ciphertext
    # decrypts under an independent cipher call with the exact placeholder
    # bytes (GCM IV is random, so we pin by key equivalence, not ciphertext
    # equality).
    assert try_decrypt_with_key(@placeholder_key, ciphertext) == {:ok, @plaintext}
    assert try_decrypt_with_key(@real_key, ciphertext) in [:error, {:ok, :error}]
  end

  test "placeholder fallback path is disclosure-pinned: no runtime prod guard is enforced" do
    # Row 5 typed disclosure: vault.ex documents "must NOT be used in
    # production" in its moduledoc, but init/1 enforces nothing -- an unset
    # CLOAK_KEY in prod boots the vault silently on the publicly-committed
    # placeholder. Test-only boundary (P1-4): pin current behavior; adding a
    # prod guard is a decision, not this lane's diff.
    System.delete_env("CLOAK_KEY")

    start_supervised!(Vault)

    # Real observable: with no CLOAK_KEY, the running vault's default
    # cipher is keyed by the publicly-committed placeholder bytes.
    {:ok, ciphertext} = Vault.encrypt(@plaintext)

    assert try_decrypt_with_key(@placeholder_key, ciphertext) == {:ok, @plaintext}
  end

  # Find the live supervisor owning Xaas.Vault, retrying because the vault
  # can be restarting under its supervisor while we look.
  defp find_vault_supervisor(tries \\ 50)

  defp find_vault_supervisor(0), do: nil

  defp find_vault_supervisor(tries) do
    case Process.whereis(Vault) do
      nil ->
        Process.sleep(50)
        find_vault_supervisor(tries - 1)

      pid ->
        # OTP 28: `:ancestors` is not an accepted process_info item here;
        # read the proc_lib `$ancestors` entry from the process dictionary.
        case :erlang.process_info(pid, :dictionary) do
          {:dictionary, dict} ->
            case Keyword.fetch(dict, :"$ancestors") do
              {:ok, [supervisor | _]} -> supervisor
              _ -> retry(tries)
            end

          _ ->
            retry(tries)
        end
    end
  end

  defp retry(tries) do
    Process.sleep(50)
    find_vault_supervisor(tries - 1)
  end

  # Real collaborator: an independent cipher call with the exact same
  # AES.GCM.V1 parameters as Xaas.Vault's default cipher. No mocks.

  # Returns {:ok, plaintext} or :error without letting the underlying
  # :crypto failure escape.
  defp try_decrypt_with_key(key, ciphertext) do
    try do
      Cloak.Ciphers.AES.GCM.decrypt(ciphertext,
        tag: "AES.GCM.V1",
        key: key,
        iv_length: 12
      )
    rescue
      _ -> :error
    end
  end

  defp wait_until(fun, tries \\ 50)

  defp wait_until(_fun, 0), do: flunk("Xaas.Vault name did not clear")

  defp wait_until(fun, tries) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      wait_until(fun, tries - 1)
    end
  end

# OS-17 (w393/w394): prod must refuse the committed placeholder key.
# Mix.env() is compile-time, so the prod branch can't execute under
# MIX_ENV=test — this source pin is the regression tripwire; the real
# prod proof is the init/1 {:stop, ...} clause itself.
test "OS-17 PIN: prod fail-closed guard present in Xaas.Vault source" do
  source = File.read!("lib/xaas/vault.ex")
  assert source =~ ~s[{:stop, {:cloak_key_missing, :prod_refuses_placeholder_key}}]
  assert source =~ "Mix.env() == :prod"
end

end
