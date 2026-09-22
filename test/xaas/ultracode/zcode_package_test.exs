defmodule Xaas.Ultracode.ZcodePackageTest do
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.ZcodePackage

  @fake_node Path.expand("../../support/fake-node.sh", __DIR__)
  @real_cli Path.expand("~/dev/zcode-cli")

  defp cli(pkg, script? \\ true) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "zcode-pkg-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(Path.join(dir, "bin"))
    if script?, do: File.write!(Path.join(dir, "bin/zcode.js"), "")
    File.write!(Path.join(dir, "package.json"), Jason.encode!(pkg))
    dir
  end

  defp good(overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "zcode-app-cli",
        "version" => "3.12.3-26",
        "bin" => %{"zcode" => "bin/zcode.js"},
        "engines" => %{"node" => ">=22.19.0"}
      },
      overrides
    )
  end

  test "loads name, version, launcher and node floor from package.json" do
    assert {:ok, pkg} = ZcodePackage.load(cli(good()))
    assert pkg.name == "zcode-app-cli"
    assert pkg.version == "3.12.3-26"
    assert pkg.bin == "bin/zcode.js"
    assert pkg.node_floor == {22, 19, 0}
    assert File.regular?(pkg.script)
  end

  test "refuses a missing package.json with the path" do
    assert {:error, {:cli_unavailable, path}} = ZcodePackage.load("/nonexistent-zcode-cli")
    assert path == "/nonexistent-zcode-cli/package.json"
  end

  test "refuses a different package, a missing bin, an escaping bin and an unsupported range" do
    assert {:error, {:zcode_package_invalid, _, {:wrong_name, "other"}}} =
             ZcodePackage.load(cli(good(%{"name" => "other"})))

    assert {:error, {:zcode_package_invalid, _, :missing_bin_zcode}} =
             ZcodePackage.load(cli(good(%{"bin" => %{}})))

    assert {:error, {:cli_unavailable, _}} =
             ZcodePackage.load(cli(good(%{"bin" => %{"zcode" => "../../etc/passwd"}})))

    assert {:error, {:cli_unavailable, _}} = ZcodePackage.load(cli(good(), false))

    assert {:error, {:zcode_package_invalid, _, {:unsupported_engines_range, "^22"}}} =
             ZcodePackage.load(cli(good(%{"engines" => %{"node" => "^22"}})))
  end

  test "node floor is measured by running the executable" do
    {:ok, pkg} = ZcodePackage.load(cli(good()))
    assert :ok = ZcodePackage.check_node(pkg, @fake_node)

    {:ok, strict} = ZcodePackage.load(cli(good(%{"engines" => %{"node" => ">=99.0.0"}})))

    assert {:error, {:node_too_old, _, "26.8.1", ">=99.0.0"}} =
             ZcodePackage.check_node(strict, @fake_node)

    assert {:error, {:node_version_unreadable, _, _}} = ZcodePackage.check_node(pkg, "/bin/echo")
  end

  @tag skip:
         if(File.regular?(Path.join(@real_cli, "package.json")),
           do: false,
           else: "~/dev/zcode-cli not present"
         )
  test "the real ~/dev/zcode-cli package.json is admitted and the machine's node satisfies it" do
    assert {:ok, pkg} = ZcodePackage.check(@real_cli, System.find_executable("node") || "node")
    assert pkg.name == "zcode-app-cli"
    assert pkg.bin == "bin/zcode.js"
  end
end
