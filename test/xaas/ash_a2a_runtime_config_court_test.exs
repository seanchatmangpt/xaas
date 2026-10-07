defmodule Xaas.AshA2ARuntimeConfigCourtTest do
  @moduledoc """
  W720 court: the `:ash_a2a` runtime.exs posture (W701) is pinned at the
  source level. `config/runtime.exs` is NOT loaded in the test env, so this
  court reads the real file and evaluates it with the Elixir stdlib's
  `Config.Reader.read!/2` (the same machinery `mix` itself uses), passing
  `env:` per case. No mocks of owned code; the dep's refusal path is
  exercised by calling the real `AshA2A.CapabilityRelease`.
  """

  use ExUnit.Case, async: false

  @runtime_exs Path.expand("config/runtime.exs", File.cwd!())
  @dev_exs Path.expand("config/dev.exs", File.cwd!())
  @dep_release_source Path.expand(
                        "deps/ash_a2a/lib/ash_a2a/capability_release.ex",
                        File.cwd!()
                      )
  @b11_wire_source Path.expand(
                     "deps/ash_a2a/lib/ash_a2a/chicago/bench/b11_wire.ex",
                     File.cwd!()
                   )
  @refusal_source Path.expand(
                    "deps/ash_a2a/lib/ash_a2a/semantic/refusal.ex",
                    File.cwd!()
                  )

  # Minimal stub env so the prod block's fail-closed raises never fire during
  # the reader eval. Values are syntactically valid, not real credentials.
  @prod_env %{
    "DATABASE_URL" => "ecto://stub:stub@stub/stub",
    "SECRET_KEY_BASE" => String.duplicate("s", 64),
    "ONETIME_REVOKE_KEY" => String.duplicate("r", 32),
    "XAAS_A2A_DATA_DIR" => "/tmp/xaas-w720-stub-data-dir",
    "XAAS_A2A_OUTBOX_KEY" => Base.encode64(String.duplicate("o", 32)),
    "XAAS_A2A_BINDING_KEY" => Base.encode64(String.duplicate("b", 32)),
    "XAAS_A2A_CLAIM_STORE_KEY" => Base.encode64(String.duplicate("c", 32))
  }

  defp read_runtime!(env) do
    saved = Map.new(@prod_env, fn {k, _} -> {k, System.get_env(k)} end)

    System.put_env(@prod_env)

    try do
      Config.Reader.read!(@runtime_exs, env: env)
    after
      Enum.each(saved, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)
    end
  end

  # W856: config/dev.exs also carries the strict dev posture (the W752 F1
  # cluster_size fix landed there, receipt
  # docs/sjira/v26.10.6/plans/w803-dev-boot-fix.md). Pin it at source level
  # the same way the runtime.exs blocks above are pinned.
  defp read_dev! do
    Config.Reader.read!(@dev_exs, env: :dev)
  end

  describe "dev block (config/dev.exs, W803 F1 repair)" do
    # WHY this pin exists: the strict profile implies the production rule set
    # (RFC-SA2A-007) — AshA2A.ReceiptStore boot_check, deps/ash_a2a/lib/
    # ash_a2a/receipt_store.ex:191-193 refuses EKV cluster_size < 3 with
    # {:insufficient_cluster_size, n}. dev.exs previously shipped cluster_size 1
    # and every dev boot failed strict preflight; W803 fixed it to 3. This
    # assertion is the mutation gate: flipping dev.exs back to 1 (or deleting
    # the key, default 1) fails exactly here.
    test "dev ash_a2a sets security_profile :strict and lawful EKV cluster_size 3" do
      cfg = read_dev!()
      a2a = get_in(cfg, [:ash_a2a])

      assert a2a[:security_profile] == :strict
      assert a2a[:receipt_store] == AshA2A.ReceiptStore.Ekv

      ekv = a2a[:receipt_store_ekv_opts]
      # exact value 3, not just >= 3: the w803 citation fixes the minimum
      # lawful literal at the source, so a silent 2 cannot slip past either.
      assert Keyword.get(ekv, :cluster_size) == 3
    end

    test "dev receipt store data_dir is durable (non-tmp), per strict preflight" do
      ekv = get_in(read_dev!(), [:ash_a2a, :receipt_store_ekv_opts])

      data_dir = Keyword.fetch!(ekv, :data_dir)
      assert data_dir != nil
      refute String.contains?(to_string(data_dir), "/tmp")
    end
  end

  describe "prod block (config_env() == :prod)" do
    test "sets capability_release_mode :strict" do
      cfg = read_runtime!(:prod)

      assert get_in(cfg, [:ash_a2a, :capability_release_mode]) == :strict
    end

    test "pairs strict mode with the durable authority/durability half" do
      cfg = read_runtime!(:prod)
      a2a = Keyword.fetch!(cfg, :ash_a2a)

      assert a2a[:receipt_store] == AshA2A.ReceiptStore.Ekv
      assert a2a[:claim_store] == AshA2A.ConsequenceKernel.EffectClaimStore.DurableFile
      assert match?({AshA2A.Authority.Broker.Ekv, _}, a2a[:authority_broker])
      assert a2a[:kill_switch_class] == :xaas_a2a
      assert a2a[:receipt_outbox_dir] != nil and a2a[:receipt_outbox_key] != nil
    end
    # (d) kill_switch_class consistency, stated honestly:
    # prod = :xaas_a2a, test = :xaas_a2a_test. The difference is deliberate
    # (test.exs keeps the kill-switch class scoped to the test suite so a
    # test kill switch can never trip prod machinery); the *class* differs,
    # the *presence* of a kill-switch class does not. Pinned both ways.

    test "kill_switch_class presence is consistent across test.exs and prod" do
      prod_class = get_in(read_runtime!(:prod), [:ash_a2a, :kill_switch_class])
      test_class = Application.fetch_env!(:ash_a2a, :kill_switch_class)

      assert prod_class == :xaas_a2a
      assert test_class == :xaas_a2a_test
      # both configured; namespaced per env by design (see comment above)
      assert is_atom(test_class) and is_atom(prod_class)
    end
  end

  describe "test-env block (absence pin, W701 fresh-root finding)" do
    test "runtime.exs deliberately does NOT configure ash_a2a for the test env" do
      cfg = read_runtime!(:test)

      # No test block in runtime.exs touches :ash_a2a at all; test.exs owns
      # the test-env ash_a2a config (legacy_compat + InMemory broker) so that
      # :strict in compile-time config never fails the dep's own compile and
      # tests never need a durable filesystem contract.
      refute Keyword.has_key?(cfg, :ash_a2a)
      refute match?(%{}, get_in(cfg, [:ash_a2a]))
    end

    test "the test env's effective mode is NOT strict (legacy default)" do
      refute Application.get_env(:ash_a2a, :capability_release_mode) == :strict
    end
  end

  describe "strict-mode refusal path (real dep call, Chicago)" do
    test "strict mode without a release closure refuses :capability_release_closure_missing" do
      assert {:error, :capability_release_closure_missing} =
               AshA2A.CapabilityRelease.binding(
                 "w720-never-released-capability",
                 capability_release_mode: :strict
               )
    end

    test "filter_skills in strict mode without a closure refuses the same class" do
      assert {:error, :capability_release_closure_missing} =
               AshA2A.CapabilityRelease.filter_skills(
                 [%{id: "create_widget", name: "Create widget"}],
                 capability_release_mode: :strict
               )
    end

    test "dep source pins: closure-missing refusal exists and names the b11_wire bench surface" do
      release_src = File.read!(@dep_release_source)

      assert release_src =~ ":capability_release_closure_missing"
      assert release_src =~ "defmodule AshA2A.CapabilityRelease"

      # W701's observed refusal surface: the bench agents (b11_wire) are the
      # consumers that refuse :capability_release_closure_missing while
      # expanding agent cards under compile-time :strict.
      b11_src = File.read!(@b11_wire_source)
      assert File.exists?(@b11_wire_source)
      assert b11_src =~ "chicago_b11_wire_agent"

      # typed mapping of the refusal class in the semantic refusal vocabulary
      refusal_src = File.read!(@refusal_source)
      assert refusal_src =~ "capability_release_closure_missing: :refused_provenance"
    end
  end
end
