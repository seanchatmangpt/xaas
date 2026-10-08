defmodule Xaas.Ultracode.CoordinationCourtW984jrTest do
  @moduledoc """
  Lane W984jr unclaimed-family probe: coordination-surface branches the census
  showed as unexercised. Chicago discipline: real Application-env registry rows,
  real package.json on disk, real node shim subprocesses, real flock helper
  processes. Zero mocks. Each court names the mutation that dies if the court
  is deleted.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{ProviderHealth, SequencedDrain}

  @fake_node Path.expand("../../support/fake-node.sh", __DIR__)

  setup do
    reg = Application.get_env(:xaas, :ultracode_providers)

    on_exit(fn ->
      case reg do
        nil -> Application.delete_env(:xaas, :ultracode_providers)
        _ -> Application.put_env(:xaas, :ultracode_providers, reg)
      end
    end)

    :ok
  end

  defp cli(node_range) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "coord-court-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(Path.join(dir, "bin"))
    File.write!(Path.join(dir, "bin/zcode.js"), "")

    File.write!(
      Path.join(dir, "package.json"),
      Jason.encode!(%{
        "name" => "zcode-app-cli",
        "version" => "9.9.9-test",
        "bin" => %{"zcode" => "bin/zcode.js"},
        "engines" => %{"node" => node_range}
      })
    )

    dir
  end

  describe "ProviderHealth registry fallback chain (unexercised state-bearing branches)" do
    test "a registry transport pin is used when no option is given" do
      dir = cli(">=22.19.0")

      Application.put_env(:xaas, :ultracode_providers, %{
        "pinned" => %{enabled: true, transport: %{cli_dir: dir, node_path: @fake_node}}
      })

      # Mutation rationale: deleting the `Keyword.get(transport, :cli_dir)` leg
      # of the fallback chain in check/1 makes this fall to the app-env/default
      # dir and this court dies with {:cli_unavailable, _}.
      assert {:ok, health} = ProviderHealth.check(provider: "pinned")
      assert health.zcode_version == "9.9.9-test"
      assert health.node_version == "26.8.1"
    end

    test "an explicit option beats the registry transport pin" do
      dir = cli(">=22.19.0")

      Application.put_env(:xaas, :ultracode_providers, %{
        "pinned" => %{enabled: true, transport: %{cli_dir: dir, node_path: @fake_node}}
      })

      # Mutation rationale: inverting the option-vs-pin precedence (checking the
      # pin before opts) makes the good pinned dir win and this court dies.
      assert {:error, {:cli_unavailable, _}} =
               ProviderHealth.check(provider: "pinned", cli_dir: "/nonexistent-coord-court")
    end

    test "gate/1 refuses a DISABLED provider without probing anything" do
      Application.put_env(:xaas, :ultracode_providers, %{
        "stopped" => %{enabled: false, transport: %{cli_dir: "/nonexistent-coord-court"}}
      })

      # Mutation rationale: deleting `registry_enabled?/1` (or its disabled arm)
      # lets gate/1 fall through to check/1, which would answer
      # {:cli_unavailable, _} instead of {:provider_disabled, _} — court dies.
      assert {:error, {:provider_unhealthy, {:provider_disabled, "stopped"}}} =
               ProviderHealth.gate(provider: "stopped")
    end

    test "an UNKNOWN provider keeps the probe-only behavior (registry is selection's fence, not health's)" do
      Application.put_env(:xaas, :ultracode_providers, %{})

      # Mutation rationale: deleting the `{:error, {:unknown_provider, _}} ->
      # :ok` arm of registry_enabled?/1 turns every unregistered provider into
      # a refusal; this court dies because the probe answers :ok.
      assert :ok =
               ProviderHealth.gate(
                 provider: "never-registered-w984jr",
                 cli_dir: cli(">=22.19.0"),
                 node_path: @fake_node
               )
    end
  end

  describe "SequencedDrain drain/1 loop bookkeeping (unexercised state-bearing branch)" do
    test "max_batches: 0 halts at the loop base case without touching any repo" do
      # Mutation rationale: deleting the `loop(_state, 0, acc)` base case (or
      # the `Keyword.get(opts, :max_batches, 12)` bound) makes drain/1 either
      # raise (no clause) or run a real batch against Repos/Sensing — this
      # court dies either way because the base case must answer immediately.
      assert {:ok, {:max_batches, []}} =
               SequencedDrain.drain(canonical: System.tmp_dir!(), max_batches: 0)
    end
  end
end
