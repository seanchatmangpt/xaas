defmodule Xaas.Vault.DepthCourtTest do
  @moduledoc """
  Lane W984dl — Vault-family coverage burn-down depth court (G1 "Core
  Security & Vault" per the seal-manifest group taxonomy).

  Census (CamelCase-aware map of `lib/xaas/vault*`): the family is exactly
  one module, `Xaas.Vault` (`lib/xaas/vault.ex`), a `Cloak.Vault` used by
  `AshCloak` for `Xaas.Accounts.Token` and `Xaas.Platform.Webhook`.
  Prior coverage: `test/xaas/vault_env_guard_test.exs` (W349, 4 tests)
  pins the `CLOAK_KEY` env-override contract and the OS-17 prod-guard
  source pin. This court adds the *refusal* half the prior lane did not
  exercise: tampered ciphertext, foreign-key ciphertext, non-base64 key
  material, and boundary-shaped plaintext — all through the real public
  `Vault.encrypt/1` / `Vault.decrypt/1` API against a real vault process
  (Chicago: real collaborators, state assertions, zero mocks).

  Mutation rationale per test: each test kills a named mutant class —
  (1) a vault that returns plaintext-ish garbage instead of failing on
  tamper, (2) a keyring that silently accepts foreign-key data, (3) an
  init that tolerates malformed key material, (4) a cipher config with
  wrong IV/tag parameters that happens to pass on one input shape,
  (5) a regression of the fail-closed init contract.
  """

  use ExUnit.Case, async: false

  alias Xaas.Vault

  @valid_key Base.encode64(:crypto.strong_rand_bytes(32))
  @short_plaintext "w984dl-short"
  @empty_plaintext ""
  @large_plaintext :crypto.strong_rand_bytes(64 * 1024)

  setup do
    supervisor = find_vault_supervisor()
    assert supervisor != nil, "app-booted Xaas.Vault must be running"

    on_exit(fn ->
      System.delete_env("CLOAK_KEY")

      if is_nil(Process.whereis(Vault)) do
        {:ok, _} = Supervisor.restart_child(supervisor, Vault)
      end
    end)

    :ok = Supervisor.terminate_child(supervisor, Vault)
    wait_until(fn -> Process.whereis(Vault) == nil end)
    System.delete_env("CLOAK_KEY")
    :ok
  end

  @tag :vault_depth_court
  test "1. sealed-storage round trip: encrypt under fresh-env key decrypts to identical plaintext" do
    # Mutation rationale: kills a vault whose default cipher key ignores
    # CLOAK_KEY (the W349 lane pins the positive key-selection contract;
    # here we pin the full round trip through the public API under a
    # key that differs from both the placeholder and any prior test key,
    # so a stale-key mutant produces a decrypt mismatch).
    System.put_env("CLOAK_KEY", @valid_key)
    start_supervised!(Vault)

    for plaintext <- [@short_plaintext, @empty_plaintext, @large_plaintext] do
      {:ok, ciphertext} = Vault.encrypt(plaintext)
      assert is_binary(ciphertext)
      assert ciphertext != plaintext
      assert Vault.decrypt(ciphertext) == {:ok, plaintext}
    end
  end

  @tag :vault_depth_court
  test "2. tamper refusal: flipping one ciphertext byte yields a typed error, never plaintext" do
    # Mutation rationale: kills a decrypt path that silently truncates or
    # pads its way to a 'successful' GCM open — the auth tag must make any
    # single-bit mutation a typed {:error, _}, not garbage-with-:ok.
    System.put_env("CLOAK_KEY", @valid_key)
    start_supervised!(Vault)

    {:ok, ciphertext} = Vault.encrypt(@short_plaintext)
    assert {:ok, @short_plaintext} = Vault.decrypt(ciphertext)

    # Flip exactly one bit at every byte position of the GCM-protected
    # payload. Observed blob layout (cloak 1.1.4 AES.GCM.V1):
    # <<version::8, tag_len::8, tag_bytes, iv, ct, auth_tag>> — the
    # leading version byte sits OUTSIDE the GCM-protected region, so a
    # mutation there is tolerated (pinned below); every mutation inside
    # tag/iv/ct/tag must be a typed refusal.
    byte_count = byte_size(ciphertext)

    tolerated = [0]

    for pos <- 0..(byte_count - 1), pos not in tolerated do
      tampered = flip_bit_at(ciphertext, pos)
      result = Vault.decrypt(tampered)
      # Cloak's typed refusal shapes: :error or {:ok, :error} (the GCM
      # cipher maps an auth failure to {:ok, :error}); both are refusals,
      # never {:ok, plaintext}.
      assert result in [:error, {:ok, :error}] or match?({:error, _}, result),
             "expected typed refusal for tampered ciphertext at byte #{pos}, " <>
               "got: #{inspect(result)}"
    end

    # Pinned tolerance: the unauthenticated version byte can flip without
    # failing decryption. Mutation rationale: kills a mutant that adds
    # (or claims) header authentication — the current format does not
    # authenticate it, and this test fails if that changes silently.
    assert {:ok, @short_plaintext} = Vault.decrypt(flip_bit_at(ciphertext, 0))
  end

  @tag :vault_depth_court
  test "3. wrong-key refusal: ciphertext from a foreign-key vault is refused by the live vault" do
    # Mutation rationale: kills a keyring that accepts ciphertexts whose
    # GCM tag verifies under a *different* key — cross-key replay of a
    # token blob between environments must fail closed.
    System.put_env("CLOAK_KEY", @valid_key)
    start_supervised!(Vault)

    foreign_key = :crypto.strong_rand_bytes(32)

    {:ok, foreign_blob} =
      Cloak.Ciphers.AES.GCM.encrypt(@short_plaintext,
        tag: "AES.GCM.V1",
        key: foreign_key,
        iv_length: 12
      )

    result = Vault.decrypt(foreign_blob)

    # The vault must never hand back the foreign plaintext. Cloak's
    # refusal shapes here are :error or {:ok, :error} (GCM maps an auth
    # failure to {:ok, :error}); any {:ok, real_plaintext} is fail-open.
    assert result in [:error, {:ok, :error}] or match?({:error, _}, result),
           "foreign-key ciphertext must be refused, got: #{inspect(result)}"

    assert result != {:ok, @short_plaintext}

    # And symmetrically: this vault's ciphertext does not open under the
    # foreign key via an independent cipher call with identical params.
    {:ok, ours} = Vault.encrypt(@short_plaintext)

    independent =
      try do
        Cloak.Ciphers.AES.GCM.decrypt(ours,
          tag: "AES.GCM.V1",
          key: foreign_key,
          iv_length: 12
        )
      rescue
        _ -> :error
      end

    refute independent == {:ok, @short_plaintext},
           "our ciphertext must not open under the foreign key"
  end

  @tag :vault_depth_court
  test "4. malformed CLOAK_KEY: non-base64 key material refuses vault startup with a typed raise" do
    # Mutation rationale: kills an init that rescues/swallows decode
    # failure and falls back to a default (a vault booting on unknown key
    # material is worse than one that refuses to boot). Base.decode64!/1
    # raising inside init/1 must surface as a start failure, not silence.
    System.put_env("CLOAK_KEY", "not-valid-base64!!!")

    # Exceptions in GenServer init/1 must surface as a start failure, not
    # a successful boot with a swallowed fallback — a live process here is
    # a fail-open mutant.
    # start_supervised! surfaces init/1's Base.decode64! raise as a
    # RuntimeError wrapping the child failure — a typed start refusal,
    # never a live vault on unknown key material.
    assert_raise(RuntimeError, ~r/non-alphabet character|ArgumentError|failed to start child/,
                 fn -> start_supervised!(Vault) end)

    assert Process.whereis(Vault) == nil
  end

  @tag :vault_depth_court
  test "5. fail-closed init contract: absent CLOAK_KEY still yields a working vault under test env" do
    # Mutation rationale: pins that the OS-17 prod guard is *conditional*
    # — removing the `Mix.env() == :prod` condition would break dev/test
    # boot on the placeholder fallback. Real observable: with no env key,
    # the vault boots (test env) and its data is keyed by the committed
    # placeholder bytes, per the documented fallback contract.
    System.delete_env("CLOAK_KEY")
    start_supervised!(Vault)

    placeholder_key = Base.decode64!("4T4/f5PYK0d489Do8sNU8VNJHKD/1XVOLXyzHUlIkQY=")
    {:ok, ciphertext} = Vault.encrypt(@short_plaintext)
    assert Vault.decrypt(ciphertext) == {:ok, @short_plaintext}

    assert Cloak.Ciphers.AES.GCM.decrypt(ciphertext,
             tag: "AES.GCM.V1",
             key: placeholder_key,
             iv_length: 12
           ) == {:ok, @short_plaintext}
  end

  # -- helpers (no mocks: independent real cipher calls only) ------------

  defp flip_bit_at(bin, pos) when is_integer(pos) do
    <<head::binary-size(^pos), byte, tail::binary>> = bin
    <<head::binary, :erlang.bxor(byte, 1)::8, tail::binary>>
  end

  defp find_vault_supervisor(tries \\ 50)

  defp find_vault_supervisor(0), do: nil

  defp find_vault_supervisor(tries) do
    case Process.whereis(Vault) do
      nil ->
        Process.sleep(50)
        find_vault_supervisor(tries - 1)

      pid ->
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

  defp wait_until(fun, tries \\ 100)

  defp wait_until(_fun, 0), do: flunk("Xaas.Vault name did not clear")

  defp wait_until(fun, tries) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      wait_until(fun, tries - 1)
    end
  end
end
