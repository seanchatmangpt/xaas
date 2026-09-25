defmodule Xaas.Ultracode.ProviderHealthTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Chicago-style: real package.json files on disk, the real
  `~/dev/zcode-cli` checkout, and real `--version` subprocesses (the
  `fake-node.sh` shim is a real executable answering `--version` like node).
  """

  alias Xaas.Ultracode.ProviderHealth

  @fake_node Path.expand("../../support/fake-node.sh", __DIR__)
  @real_cli Path.expand("~/dev/zcode-cli")

  defp cli(node_range) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "provider-health-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
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

  test "reports zcode version, launcher and the measured node version" do
    assert {:ok, health} = ProviderHealth.check(cli_dir: cli(">=22.19.0"), node_path: @fake_node)

    assert health == %{
             zcode_version: "9.9.9-test",
             zcode_bin: "bin/zcode.js",
             node_version: "26.8.1"
           }

    assert :ok = ProviderHealth.gate(cli_dir: cli(">=22.19.0"), node_path: @fake_node)
  end

  test "a node older than engines.node is a typed unhealthy result" do
    assert {:error, {:node_too_old, _, "26.8.1", ">=99.0.0"}} =
             ProviderHealth.check(cli_dir: cli(">=99.0.0"), node_path: @fake_node)

    assert {:error, {:provider_unhealthy, {:node_too_old, _, _, _}}} =
             ProviderHealth.gate(cli_dir: cli(">=99.0.0"), node_path: @fake_node)
  end

  test "a bad CLI dir is a typed unhealthy result" do
    assert {:error, {:cli_unavailable, "/nonexistent-zcode-cli/package.json"}} =
             ProviderHealth.check(cli_dir: "/nonexistent-zcode-cli", node_path: @fake_node)

    assert {:error, {:provider_unhealthy, {:cli_unavailable, _}}} =
             ProviderHealth.gate(cli_dir: "/nonexistent-zcode-cli", node_path: @fake_node)
  end

  test "an unresolvable node executable is a typed unhealthy result" do
    assert {:error, {:node_unavailable, "/nonexistent/node"}} =
             ProviderHealth.check(cli_dir: cli(">=22.19.0"), node_path: "/nonexistent/node")
  end

  @tag skip:
         if(File.regular?(Path.join(@real_cli, "package.json")),
           do: false,
           else: "~/dev/zcode-cli not present"
         )
  test "the real ~/dev/zcode-cli with the machine's node" do
    case ProviderHealth.check(cli_dir: @real_cli) do
      {:ok, health} ->
        assert health.zcode_bin == "bin/zcode.js"
        assert health.zcode_version =~ ~r/\A\d+\.\d+\.\d+/
        assert health.node_version =~ ~r/\A\d+\.\d+\.\d+\z/

      {:error, {:node_too_old, _node, found, needs}} ->
        # Typed, measured refusal on a machine whose node is below the floor.
        assert found =~ ~r/\A\d+\.\d+\.\d+\z/
        assert needs =~ ~r/\A>=\d+\.\d+\.\d+\z/
    end
  end
end
