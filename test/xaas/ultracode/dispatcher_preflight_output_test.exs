defmodule Xaas.Ultracode.DispatcherPreflightOutputTest do
  use ExUnit.Case, async: true

  @moduledoc """
  QUALIFIER falsifiers (test(falsifier)) for what `zcode_package_preflight` in
  `scripts/xaas-glm-failover-dispatcher.sh` LEAVES BEHIND on success: the
  `ZCODE_BIN` value every later `node "$ZCODE_BIN" ...` launch uses.

  The sibling `DispatcherPreflightTest` probes pass/fail through `--epoch bad`,
  which cannot observe `ZCODE_BIN`. Here the real function body is extracted
  from the real script with `sed`, run by a real `bash` and a real `node`, and
  the resulting `ZCODE_BIN` is printed.

  Claims attacked:

    * `ZCODE_BIN` is exactly `bin.zcode` -- but stderr is merged into the
      captured value, so any warning a Node preload (`NODE_OPTIONS=--require`)
      writes lands inside `ZCODE_BIN` and every launch then targets a file
      named "<warning>\\nbin/zcode.js".
    * The shell floor check equals the Elixir one -- but a prerelease node
      (`process.versions.node` = "22.19.0-nightly...") makes the patch
      component `NaN`, which compares neither greater nor lesser and silently
      passes a floor the Elixir side (`ZcodePackage.verify_node/2`) refuses.
    * `bin.zcode` "may not escape the CLI dir" -- a symlink that points outside
      is admitted (lexical `path.resolve` only), the same defect as
      `ZcodePackageFalsifierTest`.
  """

  @script Path.expand("../../../scripts/xaas-glm-failover-dispatcher.sh", __DIR__)

  @moduletag skip: if(System.find_executable("node"), do: false, else: "node not on PATH")

  defp tmp(prefix) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "#{prefix}-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    dir
  end

  defp cli(node_range) do
    dir = tmp("preflight-out")
    File.mkdir_p!(Path.join(dir, "bin"))
    File.write!(Path.join(dir, "bin/zcode.js"), "")

    File.write!(
      Path.join(dir, "package.json"),
      Jason.encode!(%{
        "name" => "zcode-app-cli",
        "version" => "1.0.0",
        "bin" => %{"zcode" => "bin/zcode.js"},
        "engines" => %{"node" => node_range}
      })
    )

    dir
  end

  defp preload(source) do
    path = Path.join(tmp("preflight-preload"), "preload.cjs")
    File.write!(path, source)
    path
  end

  # {:ok, zcode_bin} | :refused
  defp preflight(cli_dir, node_options \\ nil) do
    body = ~S"""
    log() { :; }
    eval "$(sed -n '/^zcode_package_preflight()/,/^}/p' "$SCRIPT")"
    ZCODE_CLI_DIR="$CLI"
    if zcode_package_preflight; then printf 'OK:%s' "$ZCODE_BIN"; else printf 'REFUSED'; fi
    """

    env =
      [{"SCRIPT", @script}, {"CLI", cli_dir}] ++
        if(node_options, do: [{"NODE_OPTIONS", node_options}], else: [])

    case System.cmd("bash", ["-c", body], env: env) do
      {"OK:" <> bin, 0} -> {:ok, bin}
      {"REFUSED", 0} -> :refused
    end
  end

  test "control: ZCODE_BIN is exactly bin.zcode" do
    assert {:ok, "bin/zcode.js"} = preflight(cli(">=1.0.0"))
  end

  test "stderr noise from a node preload does not leak into ZCODE_BIN" do
    noisy = preload(~S|console.error("(node:1) [DEP0000] Warning: preload noise");|)

    assert {:ok, "bin/zcode.js"} = preflight(cli(">=1.0.0"), "--require " <> noisy)
  end

  test "a prerelease node below the floor is refused, like ZcodePackage does" do
    spoof =
      preload(
        ~S|Object.defineProperty(process.versions, "node", {value: "22.19.0-nightly20260101", configurable: true});|
      )

    assert :refused = preflight(cli(">=22.19.5"), "--require " <> spoof)
  end

  test "control: a prerelease node at the floor is admitted" do
    spoof =
      preload(
        ~S|Object.defineProperty(process.versions, "node", {value: "22.19.5-nightly20260101", configurable: true});|
      )

    assert {:ok, "bin/zcode.js"} = preflight(cli(">=22.19.5"), "--require " <> spoof)
  end

  test "a bin.zcode symlink that resolves outside the CLI dir is refused" do
    outside = tmp("preflight-outside")
    File.write!(Path.join(outside, "evil.js"), "")

    dir = tmp("preflight-symlink")
    File.mkdir_p!(Path.join(dir, "bin"))
    :ok = File.ln_s(Path.join(outside, "evil.js"), Path.join(dir, "bin/zcode.js"))

    File.write!(
      Path.join(dir, "package.json"),
      Jason.encode!(%{
        "name" => "zcode-app-cli",
        "bin" => %{"zcode" => "bin/zcode.js"},
        "engines" => %{"node" => ">=1.0.0"}
      })
    )

    assert :refused = preflight(dir)
  end

  # Permanent guards for the real-path containment (fs.realpathSync on both
  # sides), mirroring ZcodePackageFalsifierTest.
  defp package_json(dir) do
    File.write!(
      Path.join(dir, "package.json"),
      Jason.encode!(%{
        "name" => "zcode-app-cli",
        "bin" => %{"zcode" => "bin/zcode.js"},
        "engines" => %{"node" => ">=1.0.0"}
      })
    )
  end

  test "a bin/ directory symlinked outside the CLI dir is refused" do
    outside = tmp("preflight-bindir-outside")
    File.write!(Path.join(outside, "zcode.js"), "")

    dir = tmp("preflight-bindir")
    :ok = File.ln_s(outside, Path.join(dir, "bin"))
    package_json(dir)

    assert :refused = preflight(dir)
  end

  test "a symlink loop and a dangling symlink are refused" do
    loop = tmp("preflight-loop")
    File.mkdir_p!(Path.join(loop, "bin"))
    :ok = File.ln_s("zcode.js", Path.join(loop, "bin/zcode.js"))
    package_json(loop)
    assert :refused = preflight(loop)

    dangling = tmp("preflight-dangling")
    File.mkdir_p!(Path.join(dangling, "bin"))
    :ok = File.ln_s("/nonexistent-zcode-launcher.js", Path.join(dangling, "bin/zcode.js"))
    package_json(dangling)
    assert :refused = preflight(dangling)
  end

  test "control: a symlink that stays inside the CLI dir is admitted" do
    dir = tmp("preflight-inside")
    File.mkdir_p!(Path.join(dir, "dist"))
    File.mkdir_p!(Path.join(dir, "bin"))
    File.write!(Path.join(dir, "dist/cli.js"), "")
    :ok = File.ln_s("../dist/cli.js", Path.join(dir, "bin/zcode.js"))
    package_json(dir)

    assert {:ok, "bin/zcode.js"} = preflight(dir)
  end

  test "control: a CLI dir reached through a symlinked path is admitted" do
    real = tmp("preflight-real-cli")
    File.mkdir_p!(Path.join(real, "bin"))
    File.write!(Path.join(real, "bin/zcode.js"), "")
    package_json(real)

    via = Path.join(tmp("preflight-via"), "cli-link")
    :ok = File.ln_s(real, via)

    assert {:ok, "bin/zcode.js"} = preflight(via)
  end
end
