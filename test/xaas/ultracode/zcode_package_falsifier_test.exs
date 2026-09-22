defmodule Xaas.Ultracode.ZcodePackageFalsifierTest do
  use ExUnit.Case, async: true

  @moduledoc """
  QUALIFIER falsifiers (test(falsifier)) for `Xaas.Ultracode.ZcodePackage` and
  `Xaas.Ultracode.ProviderHealth`, run against real package.json files, real
  symlinks and real executables on disk (Chicago style, no doubles).

  Claims attacked:

    * `bin.zcode` is "resolved inside the CLI dir" (moduledoc of ZcodePackage):
      a symlink inside the CLI dir that points outside it is admitted today,
      because containment is checked lexically (`Path.expand`) and never
      against the real path.
    * `ProviderHealth.check/1` returns `{:ok, %{zcode_version: String.t(), ...}}`
      (its `@type health`): a non-string `version` in package.json leaks through
      as an integer / nil.
    * `ProviderHealth.gate/1` is a lease gate the autonomic loop can call: a
      `node --version` that never returns hangs the caller forever, so the gate
      yields no typed answer at all.
  """

  alias Xaas.Ultracode.{ProviderHealth, ZcodePackage}

  @fake_node Path.expand("../../support/fake-node.sh", __DIR__)

  defp tmp(prefix) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "#{prefix}-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    dir
  end

  defp package_json(dir, overrides) do
    File.write!(
      Path.join(dir, "package.json"),
      Jason.encode!(
        Map.merge(
          %{
            "name" => "zcode-app-cli",
            "version" => "1.0.0",
            "bin" => %{"zcode" => "bin/zcode.js"},
            "engines" => %{"node" => ">=1.0.0"}
          },
          overrides
        )
      )
    )
  end

  test "a bin.zcode symlink that resolves outside the CLI dir is refused" do
    outside = tmp("zpkg-outside")
    File.write!(Path.join(outside, "evil.js"), "// not part of the CLI checkout\n")

    dir = tmp("zpkg-symlink-escape")
    File.mkdir_p!(Path.join(dir, "bin"))
    :ok = File.ln_s(Path.join(outside, "evil.js"), Path.join(dir, "bin/zcode.js"))
    package_json(dir, %{})

    assert {:error, _typed} = ZcodePackage.load(dir),
           "bin/zcode.js -> #{outside}/evil.js was admitted as a launcher inside #{dir}"
  end

  test "control: a bin.zcode symlink that stays inside the CLI dir is still admitted" do
    dir = tmp("zpkg-symlink-inside")
    File.mkdir_p!(Path.join(dir, "dist"))
    File.mkdir_p!(Path.join(dir, "bin"))
    File.write!(Path.join(dir, "dist/cli.js"), "")
    :ok = File.ln_s("../dist/cli.js", Path.join(dir, "bin/zcode.js"))
    package_json(dir, %{})

    assert {:ok, %{bin: "bin/zcode.js"}} = ZcodePackage.load(dir)
  end

  test "a non-string package.json version never leaks into the health report" do
    for version <- [123, nil, %{"major" => 1}, ["1.0.0"]] do
      dir = tmp("zpkg-version")
      File.mkdir_p!(Path.join(dir, "bin"))
      File.write!(Path.join(dir, "bin/zcode.js"), "")
      package_json(dir, %{"version" => version})

      assert {:ok, %{zcode_version: reported}} =
               ProviderHealth.check(cli_dir: dir, node_path: @fake_node)

      assert is_binary(reported),
             "package.json version #{inspect(version)} was reported as #{inspect(reported)}"
    end
  end

  test "a node whose --version never returns yields a typed answer within a bound" do
    dir = tmp("zpkg-hang")
    File.mkdir_p!(Path.join(dir, "bin"))
    File.write!(Path.join(dir, "bin/zcode.js"), "")
    package_json(dir, %{})

    hang = Path.join(dir, "hang-node.sh")
    # 5s, not forever: the orphan this test may leave behind expires by itself.
    File.write!(hang, "#!/bin/sh\nexec sleep 5\n")
    File.chmod!(hang, 0o755)

    task = Task.async(fn -> ProviderHealth.gate(cli_dir: dir, node_path: hang) end)

    case Task.yield(task, 2_000) do
      {:ok, result} ->
        assert {:error, {:provider_unhealthy, _typed}} = result

      nil ->
        Task.shutdown(task, :brutal_kill)
        flunk("ProviderHealth.gate/1 gave no answer in 2s for a node --version that hangs")
    end
  end
end
