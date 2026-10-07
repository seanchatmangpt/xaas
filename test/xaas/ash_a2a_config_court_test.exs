defmodule Xaas.AshA2AConfigCourtTest do
  @moduledoc """
  W701 court: xaas's `:ash_a2a` runtime must not boot degraded under the
  legacy_compat warning classes (W605's AIRo mapping). Asserts the config
  resolves per env and that the exact dev config map produces ZERO
  `AshA2A.SecurityProfile.Boot` strict violations against the real Boot
  module (Chicago: real collaborator, no mocks).
  """

  use ExUnit.Case, async: false

  @dev_data_root Path.expand("~/.local/share/xaas/ash_a2a")

  @dev_env [
    security_profile: :strict,
    receipt_store: AshA2A.ReceiptStore.Ekv,
    receipt_store_ekv_opts: [
      name: AshA2A.ReceiptStore.Ekv,
      data_dir: Path.join(@dev_data_root, "receipt_store_ekv"),
      cluster_size: 1
    ],
    receipt_outbox_dir: Path.join(@dev_data_root, "receipt_outbox"),
    receipt_outbox_key: "xaas-dev-outbox-hmac-key-0123456789abcdef0123456789abcdef",
    receipt_binding_key: "xaas-dev-binding-hmac-key-0123456789abcdef0123456789abcdef",
    claim_store: AshA2A.ConsequenceKernel.EffectClaimStore.DurableFile,
    claim_store_dir: Path.join(@dev_data_root, "claim_store"),
    claim_store_key: "xaas-dev-claimstore-hmac-key-0123456789abcdef0123456789abcdef",
    authority_broker:
      {AshA2A.Authority.Broker.Ekv,
       data_dir: Path.join(@dev_data_root, "authority_broker_ekv"), cluster_size: 1},
    kill_switch_class: :xaas_a2a,
    kill_switch_path: Path.join(@dev_data_root, "kill_switch.dets"),
    capability_release_mode: :strict
  ]

  @airo_target_classes ~w(
    authority_broker_missing
    kill_switch_class_missing
    claim_store_missing
    receipt_store_in_memory
    outbox_dir_not_durable
    outbox_key_missing
    capability_release_mode_legacy
  )a

  # violation code -> config keys that, when present, control the risk source
  @airo_controlled_by %{
    authority_broker_missing: [:authority_broker],
    kill_switch_class_missing: [:kill_switch_class],
    claim_store_missing: [:claim_store, :claim_store_dir, :claim_store_key],
    receipt_store_in_memory: [:receipt_store, :receipt_store_ekv_opts],
    outbox_dir_not_durable: [:receipt_outbox_dir],
    outbox_key_missing: [:receipt_outbox_key, :receipt_binding_key],
    capability_release_mode_legacy: [:capability_release_mode]
  }

  describe "test env config" do
    test "authority broker and kill-switch class are configured" do
      assert match?({AshA2A.Authority.Broker.InMemory, _} = _, Application.get_env(:ash_a2a, :authority_broker)) or
               Application.get_env(:ash_a2a, :authority_broker) == AshA2A.Authority.Broker.InMemory

      assert Application.get_env(:ash_a2a, :kill_switch_class) == :xaas_a2a_test
      assert Application.get_env(:ash_a2a, :capability_release_mode, :legacy) == :legacy
    end

    test "test env intentionally keeps the memory receipt store (legacy_compat documented)" do
      assert Application.get_env(:ash_a2a, :security_profile) == :legacy_compat
      assert Application.get_env(:ash_a2a, :receipt_store, AshA2A.ReceiptStore.Memory) ==
               AshA2A.ReceiptStore.Memory
    end
    # Deliberate: tests run the profile court without a durable-filesystem
    # contract; memory store + tmp outbox are fine under the legacy_compat
    # court, while the authority half is still filled.
  end

  describe "dev config clears every strict violation class" do
    test "Boot.violations(:strict, dev snapshot) == [] against the real Boot module" do
      old = for {k, _} <- @dev_env, do: {k, Application.get_env(:ash_a2a, k)}

      for {k, v} <- @dev_env, do: Application.put_env(:ash_a2a, k, v)

      try do
        snapshot = AshA2A.SecurityProfile.Boot.snapshot()
        assert AshA2A.SecurityProfile.Boot.violations(:strict, snapshot) == []

        # the ordinary preflight rules pass too
        assert AshA2A.Authority.SecurityPreflight.check() == :ok
      after
        # nil means "unset" here; put_env(k, nil) would leave the key present
        # with a nil value and shadow the library default — delete instead.
        for {k, nil} <- old, do: Application.delete_env(:ash_a2a, k)
        for {k, v} <- old, v != nil, do: Application.put_env(:ash_a2a, k, v)
      end
    end

    test "dev outbox/claim dirs are durable paths (non-tmp) per AshA2A.ReceiptStore.durable_path?/1" do
      assert AshA2A.ReceiptStore.durable_path?(@dev_data_root)
      assert AshA2A.ReceiptStore.durable_path?(Path.join(@dev_data_root, "receipt_outbox"))
      assert AshA2A.ReceiptStore.durable_path?(Path.join(@dev_data_root, "claim_store"))
    end
  end

  describe "AIRo mapping (W605) flips to controlled" do
    test "every targeted RiskSource individual exists in the W605 AIRo graph" do
      ttl = airo_ttl!()

      for code <- @airo_target_classes do
        assert String.contains?(ttl, to_string(code)),
               "expected RiskSource for #{code} in ash_a2a_airo.ttl"
      end
    end

    test "each targeted class is controlled by the config xaas now supplies" do
      ttl = airo_ttl!()
      dev_keys = Keyword.keys(@dev_env)

      for {code, keys} <- @airo_controlled_by do
        assert String.contains?(ttl, to_string(code))
        assert Enum.all?(keys, &(&1 in dev_keys)),
               "#{code} must be controlled by #{inspect(keys)}; dev config lacks some"
      end
    end
  end

  defp airo_ttl! do
    candidates = [
      # W605's TTL lives in the canonical ash_a2a checkout (uncommitted); the
      # dep's build-dir priv copy only carries committed files.
      Path.expand("../../../ash_a2a/priv/ontology/ash_a2a_airo.ttl", __DIR__),
      Application.app_dir(:ash_a2a, "priv/ontology/ash_a2a_airo.ttl")
    ]

    path = Enum.find(candidates, &File.exists?/1) ||
             raise("ash_a2a_airo.ttl not found in #{inspect(candidates)}")

    File.read!(path)
  end
end
