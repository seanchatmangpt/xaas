defmodule Xaas.Ultracode.DispatcherPreflightTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Chicago-style falsifiers for `zcode_package_preflight` in
  `scripts/xaas-glm-failover-dispatcher.sh`: the real script, a real `bash`
  and the real `node` on PATH run against real package.json files on disk.

  `--epoch bad` is the probe: the script runs the package preflight before it
  validates the epoch, so a preflight that PASSES ends at `bad --epoch value`
  (exit 2, no database touched) and a preflight that FAILS ends at exit 127
  with a typed `zcode package preflight FAILED: <reason>` line. A raw Node
  stack trace in that line is a defect: the Elixir mirror
  (`Xaas.Ultracode.ZcodePackage`) returns a typed error for every one of these
  inputs, so the shell side must too.
  """

  @script Path.expand("../../../scripts/xaas-glm-failover-dispatcher.sh", __DIR__)

  @moduletag skip: if(System.find_executable("node"), do: false, else: "node not on PATH")

  defp cli(package_json, script? \\ true) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "preflight-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(Path.join(dir, "bin"))
    if script?, do: File.write!(Path.join(dir, "bin/zcode.js"), "")
    File.write!(Path.join(dir, "package.json"), package_json)
    dir
  end

  defp good(overrides \\ %{}) do
    %{
      "name" => "zcode-app-cli",
      "version" => "1.0.0",
      "bin" => %{"zcode" => "bin/zcode.js"},
      "engines" => %{"node" => ">=1.0.0"}
    }
    |> Map.merge(overrides)
    |> Jason.encode!()
  end

  defp preflight(cli_dir) do
    state = Path.join(System.tmp_dir!(), "preflight-state-#{System.unique_integer([:positive])}")

    System.cmd("bash", [@script, "--epoch", "bad"],
      env: [{"ZCODE_CLI_DIR", cli_dir}, {"STATE_DIR", state}],
      stderr_to_stdout: true
    )
  end

  defp assert_typed_refusal({out, status}, reason) do
    assert status == 127, "expected exit 127, got #{status}: #{out}"
    assert out =~ "zcode package preflight FAILED: " <> reason, out
    refute out =~ ~r/^\s+at .*\(node:|TypeError|SyntaxError|node:internal|node:fs/m, out
  end

  test "an admissible package passes the preflight (stops at the epoch check, exit 2)" do
    assert {out, 2} = preflight(cli(good()))
    assert out =~ "bad --epoch value"
  end

  test "a whitespace-padded >=X.Y.Z floor is admitted, like ZcodePackage" do
    assert {_out, 2} = preflight(cli(good(%{"engines" => %{"node" => " >= 1.0.0 "}})))
  end

  test "a missing package.json is typed" do
    assert_typed_refusal(preflight("/nonexistent-zcode-cli"), "cli_unavailable: cannot read")
  end

  test "a wrong package name is typed" do
    assert_typed_refusal(preflight(cli(good(%{"name" => "other"}))), "wrong package name: other")
  end

  test "a node below engines.node is typed" do
    assert_typed_refusal(
      preflight(cli(good(%{"engines" => %{"node" => ">=999.0.0"}}))),
      "node "
    )
  end

  test "a launcher that does not exist is typed, not a Node stack trace" do
    assert_typed_refusal(preflight(cli(good(), false)), "cli_unavailable: launcher missing")
  end

  test "a launcher that escapes the CLI dir is typed" do
    assert_typed_refusal(
      preflight(cli(good(%{"bin" => %{"zcode" => "../../etc/hosts"}}))),
      "launcher escapes CLI dir"
    )
  end

  test "a non-string bin.zcode is typed, not a Node stack trace" do
    assert_typed_refusal(
      preflight(cli(good(%{"bin" => %{"zcode" => 5}}))),
      "package.json has no bin.zcode"
    )
  end

  test "a package.json that is JSON null is typed, not a Node stack trace" do
    assert_typed_refusal(preflight(cli("null")), "zcode_package_invalid")
  end

  test "a package.json that is not JSON is typed" do
    assert_typed_refusal(preflight(cli("{oops")), "zcode_package_invalid")
  end

  test "an unsupported engines.node range is typed" do
    assert_typed_refusal(
      preflight(cli(good(%{"engines" => %{"node" => "^22"}}))),
      "unsupported engines.node: ^22"
    )
  end

  test "the real ~/dev/zcode-cli passes the preflight when present" do
    real = Path.expand("~/dev/zcode-cli")

    if File.regular?(Path.join(real, "package.json")) do
      assert {out, 2} = preflight(real)
      assert out =~ "bad --epoch value"
    end
  end
end
