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

  Repair (2026-09-21): containment is now decided on real paths (Elixir walk of
  `File.read_link/1`, shell `fs.realpathSync`) and the `--version` probe runs
  under a process-group deadline. The extra tests below are the permanent
  guards: dir symlinks, chains, loops, dangling links, a symlinked CLI dir, and
  a hung probe whose grandchild must not outlive the answer.
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

  defp hanging_node(dir, body \\ "exec sleep 5\n") do
    path = Path.join(dir, "hang-node.sh")
    # 5s, not forever: an orphan a broken bound might leave expires by itself.
    File.write!(path, "#!/bin/sh\n" <> body)
    File.chmod!(path, 0o755)
    path
  end

  test "a node whose --version never returns yields a typed answer within a bound" do
    dir = tmp("zpkg-hang")
    File.mkdir_p!(Path.join(dir, "bin"))
    File.write!(Path.join(dir, "bin/zcode.js"), "")
    package_json(dir, %{})
    hang = hanging_node(dir)

    task =
      Task.async(fn ->
        ProviderHealth.gate(cli_dir: dir, node_path: hang, node_version_timeout_ms: 500)
      end)

    case Task.yield(task, 2_000) do
      {:ok, result} ->
        assert {:error,
                {:provider_unhealthy, {:node_version_unreadable, ^hang, "timeout after 500ms"}}} =
                 result

      nil ->
        Task.shutdown(task, :brutal_kill)
        flunk("ProviderHealth.gate/1 gave no answer in 2s for a node --version that hangs")
    end
  end

  test "the default --version deadline is finite and small enough for a lease gate" do
    assert ZcodePackage.default_version_timeout_ms() in 1..30_000
  end

  test "a timed-out --version probe reaps its whole process group, grandchild included" do
    dir = tmp("zpkg-reap")
    File.mkdir_p!(Path.join(dir, "bin"))
    File.write!(Path.join(dir, "bin/zcode.js"), "")
    package_json(dir, %{})
    pidfile = Path.join(dir, "grandchild.pid")

    # The shim forks a background grandchild (a shim that delegates to the real
    # node) and waits on it: killing only the leader would orphan the child.
    # The deadline is generous on purpose: under a loaded suite the shim must
    # have started (and written the pidfile) before the probe is killed, else
    # there is no grandchild to reap and the test would be vacuous.
    hang = hanging_node(dir, "sleep 30 &\necho $! > '#{pidfile}'\nwait\n")

    assert {:error, {:node_version_unreadable, ^hang, "timeout after 3000ms"}} =
             ProviderHealth.check(cli_dir: dir, node_path: hang, node_version_timeout_ms: 3_000)

    grandchild = pidfile |> File.read!() |> String.trim() |> String.to_integer()

    # `kill -0` exits non-zero once the pid no longer exists.
    {_, status} = System.cmd("/bin/kill", ["-0", "#{grandchild}"], stderr_to_stdout: true)
    assert status != 0, "grandchild #{grandchild} of a timed-out --version probe is still alive"
  end

  describe "bin.zcode containment is decided on real paths" do
    defp cli_with_bin_link(link_target) do
      dir = tmp("zpkg-link")
      File.mkdir_p!(Path.join(dir, "bin"))
      :ok = File.ln_s(link_target, Path.join(dir, "bin/zcode.js"))
      package_json(dir, %{})
      dir
    end

    test "a chain of symlinks that ends outside the CLI dir is refused" do
      outside = tmp("zpkg-chain-outside")
      File.write!(Path.join(outside, "evil.js"), "")

      dir = tmp("zpkg-chain")
      File.mkdir_p!(Path.join(dir, "bin"))
      File.mkdir_p!(Path.join(dir, "dist"))
      :ok = File.ln_s(Path.join(outside, "evil.js"), Path.join(dir, "dist/hop.js"))
      :ok = File.ln_s("../dist/hop.js", Path.join(dir, "bin/zcode.js"))
      package_json(dir, %{})

      assert {:error, {:cli_unavailable, _}} = ZcodePackage.load(dir)
    end

    test "a bin/ directory symlinked outside the CLI dir is refused" do
      outside = tmp("zpkg-bindir-outside")
      File.write!(Path.join(outside, "zcode.js"), "")

      dir = tmp("zpkg-bindir")
      :ok = File.ln_s(outside, Path.join(dir, "bin"))
      package_json(dir, %{})

      assert {:error, {:cli_unavailable, _}} = ZcodePackage.load(dir)
    end

    test "a symlink loop and a dangling symlink are refused, not crashed on" do
      dir = cli_with_bin_link("zcode.js")
      assert {:error, {:cli_unavailable, _}} = ZcodePackage.load(dir), "self-loop"

      dangling = cli_with_bin_link("/nonexistent-zcode-launcher.js")
      assert {:error, {:cli_unavailable, _}} = ZcodePackage.load(dangling), "dangling"
    end

    test "control: a CLI dir reached through a symlinked path is admitted" do
      real = tmp("zpkg-real-cli")
      File.mkdir_p!(Path.join(real, "bin"))
      File.write!(Path.join(real, "bin/zcode.js"), "")
      package_json(real, %{})

      via = Path.join(tmp("zpkg-via"), "cli-link")
      :ok = File.ln_s(real, via)

      assert {:ok, %{bin: "bin/zcode.js", dir: ^via}} = ZcodePackage.load(via)
    end
  end
end
