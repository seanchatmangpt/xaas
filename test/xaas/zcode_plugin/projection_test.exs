defmodule Xaas.ZcodePlugin.ProjectionTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Real Chicago-style qualification of the ggen-owned ZCode plugin project
  (`priv/zcode_plugin/`): the committed projection under `marketplace/` must be
  exactly what a real `ggen sync run` produces from `ontology.ttl` + the
  repo-local packs under `packs/` (zcode-plugin-pack, ultracode-actuation-lease-pack,
  pinned by `ggen.lock`), and the projected manifests must agree with each other.

  The real `ggen` binary is the collaborator (run in a temp copy of the
  project, so the working tree is never rewritten). Without `ggen` on PATH the
  drift test is a named skip, never a silent pass.
  """

  @project "priv/zcode_plugin"
  @marketplace Path.join(@project, "marketplace")
  @plugin Path.join(@marketplace, "xaas-fabric")

  @ggen_present System.find_executable("ggen") != nil

  defp files_under(root) do
    root
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.reject(&File.dir?/1)
    |> Map.new(fn path -> {Path.relative_to(path, root), File.read!(path)} end)
  end

  @tag skip: if(@ggen_present, do: false, else: "ggen binary not on PATH")
  test "the committed projection is exactly what ggen sync renders from the ontology" do
    # run_uid convention: wall clock + unique_integer (cross-VM collision
    # impossible among concurrent `mix test` VMs sharing $TMPDIR).
    tmp =
      Path.join(
        System.tmp_dir!(),
        "xaas-zcode-plugin-sync-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf(tmp) end)

    for entry <- ["ggen.toml", "ggen.lock", "ontology.ttl", "templates", "packs"] do
      File.cp_r!(Path.join(@project, entry), Path.join(tmp, entry))
    end

    {_out, 0} = System.cmd("ggen", ["sync", "run"], cd: tmp, stderr_to_stdout: true)

    fresh = files_under(Path.join(tmp, "marketplace"))
    committed = files_under(@marketplace)

    assert Map.keys(fresh) |> Enum.sort() == Map.keys(committed) |> Enum.sort()

    for {path, content} <- fresh do
      assert committed[path] == content,
             "projection drift in #{path}: re-run `ggen sync run` in #{@project}"
    end
  end

  test "marketplace, plugin, mcp and hook manifests agree with each other" do
    market =
      @marketplace
      |> Path.join(".claude-plugin/marketplace.json")
      |> File.read!()
      |> Jason.decode!()

    plugin = @plugin |> Path.join(".zcode-plugin/plugin.json") |> File.read!() |> Jason.decode!()
    mcp = @plugin |> Path.join(".mcp.json") |> File.read!() |> Jason.decode!()
    hooks = @plugin |> Path.join("hooks/hooks.json") |> File.read!() |> Jason.decode!()

    [%{"name" => name, "source" => source}] = market["plugins"]
    assert name == plugin["name"]
    assert File.dir?(Path.join(@marketplace, source))

    [token_key] = Map.keys(plugin["userConfig"])

    assert mcp["mcpServers"]["xaas-execution"]["headers"]["Authorization"] ==
             "Bearer ${user_config.#{token_key}}"

    [%{"hooks" => [%{"type" => "command", "command" => command, "timeout" => timeout}]}] =
      hooks["hooks"]["PreToolUse"]

    assert is_integer(timeout) and timeout > 0
    assert command =~ "${CLAUDE_PLUGIN_ROOT}/scripts/xaas-gate.mjs"
    assert File.regular?(Path.join(@plugin, "scripts/xaas-gate.mjs"))
    assert File.regular?(Path.join(@plugin, "scripts/xaas-lease.mjs"))
  end

  test "no top-level generated/ directory exists" do
    refute File.exists?("generated")
  end
end
