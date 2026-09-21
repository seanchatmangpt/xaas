defmodule Xaas.Ultracode.FabricRedeployTest do
  @moduledoc """
  Chicago-style qualification of the wave-9 REDUCE innovation
  (`mix xaas.fabric.redeploy`): real rendered-plugin trees, real staging,
  real atomic rename, real digest verification. Nothing mocked.

  EXPLICIT-CUT LAW: no test ever runs a cut against the host paths. Every
  mutating test redirects BOTH `:source_dir` and `:cache_root` into
  per-test tmp fixtures; the one test over the REAL rendered projection
  (`priv/zcode_plugin/marketplace/xaas-fabric`) is plan-only -- a pure
  read proving the command's default subject is the real tree.
  """

  use ExUnit.Case, async: true

  @moduletag :ultracode

  alias Xaas.Ultracode.FabricRedeploy

  @plugin_json_relpath ".zcode-plugin/plugin.json"

  defp mktmp(tag) do
    path =
      Path.join(
        System.tmp_dir!(),
        "xaas_w9_#{tag}_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(path)
    on_exit(fn -> File.rm_rf!(path) end)
    path
  end

  defp digest(path) do
    case File.read(path) do
      {:ok, body} -> "sha256:" <> Base.encode16(:crypto.hash(:sha256, body), case: :lower)
      {:error, _} -> :missing
    end
  end

  describe "plan/1 (pure reads; the explicit-cut default)" do
    test "plans the real rendered projection without touching the host" do
      assert {:ok, plan} = FabricRedeploy.plan()

      # The REAL rendered tree: real version, real files, no host writes.
      assert Regex.match?(~r/^\d+\.\d+\.\d+$/, plan.version)
      assert plan.source_dir == Path.expand(FabricRedeploy.default_source_dir())
      assert String.starts_with?(plan.target_dir, FabricRedeploy.default_cache_root())
      assert plan.file_count > 0
      assert plan.total_bytes > 0

      assert MapSet.new(Enum.map(plan.files, & &1.relative))
             |> MapSet.member?(@plugin_json_relpath)

      assert Enum.all?(plan.files, fn file ->
               Regex.match?(~r/\Asha256:[0-9a-f]{64}\z/, file.digest) and file.bytes > 0
             end)
    end

    test "plans a fresh install: target absent, cut would change" do
      %{source: source, cache_root: cache_root} = context_fixture()

      assert {:ok, plan} = FabricRedeploy.plan(source_dir: source, cache_root: cache_root)

      assert plan.version == "26.9.19"
      assert plan.target_dir == Path.join(cache_root, "26.9.19")
      assert plan.target_exists? == false
      assert plan.cut_would_change? == true
      assert plan.file_count == 3
      assert plan.differing_files == []
    end

    test "diffs an existing target that already matches" do
      %{source: source, cache_root: cache_root} = ctx = context_fixture()

      assert {:ok, _} =
               FabricRedeploy.redeploy(cut: true, source_dir: source, cache_root: cache_root)

      assert {:ok, plan} = FabricRedeploy.plan(source_dir: source, cache_root: cache_root)
      assert plan.target_exists? == true
      assert plan.differing_files == []
      assert plan.cut_would_change? == false
      assert plan.file_count == ctx.expected_count
    end

    test "names exactly the files that differ from a stale target" do
      %{source: source, cache_root: cache_root} = context_fixture()

      assert {:ok, _} =
               FabricRedeploy.redeploy(cut: true, source_dir: source, cache_root: cache_root)

      File.write!(Path.join([cache_root, "26.9.19", "README.md"]), "# stale bytes\n")

      assert {:ok, plan} = FabricRedeploy.plan(source_dir: source, cache_root: cache_root)
      assert plan.differing_files == ["README.md"]
      assert plan.cut_would_change? == true
    end

    test "refuses a missing or malformed plugin projection" do
      %{source: source, cache_root: cache_root} = context_fixture()

      assert {:error, {:refused_redeploy, {:missing_plugin_json, _}}} =
               FabricRedeploy.plan(source_dir: Path.join(source, "nope"), cache_root: cache_root)

      File.write!(Path.join(source, @plugin_json_relpath), "not json {")

      assert {:error, {:refused_redeploy, :invalid_plugin_json}} =
               FabricRedeploy.plan(source_dir: source, cache_root: cache_root)
    end
  end

  describe "redeploy/1 (explicit cut; redirected cache root)" do
    test "refuses the cut without the explicit flag and touches nothing" do
      %{source: source, cache_root: cache_root} = context_fixture()

      assert {:error, {:refused_redeploy, :cut_required}} =
               FabricRedeploy.redeploy(source_dir: source, cache_root: cache_root)

      refute File.exists?(cache_root)
    end

    test "performs a real staged, digest-verified swap and writes the receipt" do
      %{source: source, cache_root: cache_root} = context_fixture()

      assert {:ok, receipt} =
               FabricRedeploy.redeploy(cut: true, source_dir: source, cache_root: cache_root)

      target = Path.join(cache_root, "26.9.19")
      assert receipt.target_dir == target
      assert receipt.version == "26.9.19"
      assert receipt.file_count == 3
      assert Regex.match?(~r/\A\d{4}-\d{2}-\d{2}T/, DateTime.to_iso8601(receipt.cut_at))

      # Every planned digest landed byte-exact at the target.
      for {relative, expected} <- receipt.digests do
        assert digest(Path.join(target, relative)) == expected
      end

      # The staging directory is gone (renamed, not copied).
      refute File.exists?(Path.join(cache_root, ".redeploy-staging-0"))

      # The receipt is real JSON on disk beside the plugin manifest.
      {:ok, body} = File.read(Path.join(target, "redeploy-receipt.json"))
      assert {:ok, parsed} = Jason.decode(body)
      assert parsed["version"] == "26.9.19"
      assert parsed["file_count"] == 3
    end

    test "is idempotent: a second cut re-lands identical digests" do
      %{source: source, cache_root: cache_root} = context_fixture()
      opts = [cut: true, source_dir: source, cache_root: cache_root]

      assert {:ok, first} = FabricRedeploy.redeploy(opts)
      assert {:ok, second} = FabricRedeploy.redeploy(opts)

      assert first.digests == second.digests

      assert {:ok, plan} = FabricRedeploy.plan(source_dir: source, cache_root: cache_root)
      assert plan.differing_files == []
    end

    test "the previous version directory is never destroyed by a newer cut" do
      %{source: source, cache_root: cache_root} = context_fixture()

      assert {:ok, _} =
               FabricRedeploy.redeploy(cut: true, source_dir: source, cache_root: cache_root)

      File.write!(
        Path.join(source, @plugin_json_relpath),
        ~s({"name": "xaas-fabric", "version": "26.9.20"})
      )

      assert {:ok, _} =
               FabricRedeploy.redeploy(cut: true, source_dir: source, cache_root: cache_root)

      assert File.dir?(Path.join(cache_root, "26.9.19"))
      assert File.dir?(Path.join(cache_root, "26.9.20"))
    end
  end

  # A per-test context whose tmp dirs are freshly created (some tests mutate
  # the fixture and need their own copy).
  defp context_fixture do
    base = mktmp("fabric-redeploy-ctx")
    source = Path.join(base, "xaas-fabric")
    cache_root = Path.join(base, "cache")

    File.mkdir_p!(Path.join(source, ".zcode-plugin"))
    File.mkdir_p!(Path.join(source, "scripts"))

    File.write!(
      Path.join(source, @plugin_json_relpath),
      ~s({"name": "xaas-fabric", "version": "26.9.19"})
    )

    File.write!(
      Path.join([source, "scripts", "xaas-gate.mjs"]),
      "export function gate() { return {admit: true}; }\n"
    )

    File.write!(Path.join(source, "README.md"), "# xaas-fabric rendered projection\n")

    %{source: source, cache_root: cache_root, expected_count: 3}
  end
end
