defmodule Xaas.Ultracode.FabricRedeploy do
  @moduledoc """
  REDUCE (wave-9 ERRC): the manual xaas-fabric plugin redeploy procedure --
  compile the app, verify the rendered plugin projection under
  `priv/zcode_plugin/marketplace/xaas-fabric/`, swap it into the local zcode
  plugin cache -- collapsed into ONE documented command:

      mix xaas.fabric.redeploy          # byte-digest plan only
      mix xaas.fabric.redeploy --cut    # perform the swap

  ## Explicit-cut semantics

  WITHOUT the cut, nothing on the host is touched: `plan/1` reads the real
  rendered projection and returns exactly what a cut WOULD do -- the plugin
  version, every file with its sha256 digest, the versioned target directory
  under the plugin cache, and which target files (if any) already differ.
  WITH the cut, the swap is still narrowly mechanical:

    1. stage the source tree into a unique staging sibling inside the cache
       root (never writing through the target path mid-copy),
    2. re-verify every staged file's digest against the plan (a torn or
       partial copy is refused, never swapped in),
    3. atomically `rename` the staging directory over the versioned target,
    4. write a JSON receipt (`redeploy-receipt.json`) beside the plugin
       manifest, recording when the cut happened and the exact digests.

  The previous version's directory is never deleted (zcode's plugin cache is
  version-per-directory), so a bad cut is recoverable by re-pointing the
  plugin at the prior version; no force-push of the host, ever.

  The test suite NEVER auto-runs a cut against the host: tests exercise
  `plan/1` (pure reads) and `redeploy/1` with `:cache_root` (and, for
  synthetic fixtures, `:source_dir`) redirected into tmp directories.
  """

  @default_source_dir "priv/zcode_plugin/marketplace/xaas-fabric"

  @default_cache_root Path.expand(
                        "~/.zcode/cli/plugins/cache/xaas-fabric-marketplace/xaas-fabric"
                      )

  @plugin_json_relpath ".zcode-plugin/plugin.json"
  @receipt_relpath "redeploy-receipt.json"
  @version_pattern ~r/^\d+\.\d+\.\d+$/

  @doc "The rendered plugin projection this module swaps (repo-relative)."
  def default_source_dir, do: @default_source_dir

  @doc "The plugin cache root the swap targets by default."
  def default_cache_root, do: @default_cache_root

  @type plan :: %{
          version: String.t(),
          source_dir: String.t(),
          cache_root: String.t(),
          target_dir: String.t(),
          file_count: pos_integer(),
          total_bytes: non_neg_integer(),
          target_exists?: boolean(),
          differing_files: [String.t()],
          cut_would_change?: boolean(),
          files: [%{relative: String.t(), digest: String.t(), bytes: pos_integer()}]
        }

  @doc """
  Reads the real rendered plugin projection and computes the exact swap
  plan: every file digest, the versioned target directory, and whether the
  target already exists or differs. Pure: reads the source (and the target,
  for the diff), writes nothing.
  """
  @spec plan(keyword()) :: {:ok, plan()} | {:error, term()}
  def plan(opts \\ []) when is_list(opts) do
    source_dir = opts |> Keyword.get(:source_dir, @default_source_dir) |> Path.expand()
    cache_root = opts |> Keyword.get(:cache_root, @default_cache_root) |> Path.expand()

    with :ok <- source_readable?(source_dir),
         {:ok, version} <- plugin_version(source_dir) do
      files = source_files(source_dir)
      target_dir = Path.join(cache_root, version)
      target_exists? = File.dir?(target_dir)
      differing = differing_files(files, target_dir)

      {:ok,
       %{
         version: version,
         source_dir: source_dir,
         cache_root: cache_root,
         target_dir: target_dir,
         file_count: length(files),
         total_bytes: Enum.sum(Enum.map(files, & &1.bytes)),
         target_exists?: target_exists?,
         differing_files: differing,
         cut_would_change?: not target_exists? or differing != [],
         files: files
       }}
    end
  end

  @doc """
  Performs the compile-verified swap. Requires `opts[:cut]` -- without it
  this is a typed refusal and NOTHING happens (`{:error,
  {:refused_redeploy, :cut_required}}`); the plan-only path is `plan/1`.
  With the cut: stage -> verify digests -> atomic rename -> receipt.
  """
  @spec redeploy(keyword()) :: {:ok, map()} | {:error, term()}
  def redeploy(opts \\ []) when is_list(opts) do
    with :ok <- require_cut(opts),
         {:ok, planned} <- plan(opts) do
      stage_and_swap(planned)
    end
  end

  defp require_cut(opts) do
    if Keyword.get(opts, :cut, false),
      do: :ok,
      else: {:error, {:refused_redeploy, :cut_required}}
  end

  defp source_readable?(source_dir) do
    if File.regular?(Path.join(source_dir, @plugin_json_relpath)),
      do: :ok,
      else: {:error, {:refused_redeploy, {:missing_plugin_json, source_dir}}}
  end

  defp plugin_version(source_dir) do
    with {:ok, body} <- File.read(Path.join(source_dir, @plugin_json_relpath)),
         {:ok, json} <- Jason.decode(body),
         version when is_binary(version) <- json["version"],
         true <- Regex.match?(@version_pattern, version) do
      {:ok, version}
    else
      _ -> {:error, {:refused_redeploy, :invalid_plugin_json}}
    end
  end

  defp source_files(source_dir) do
    source_dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.sort()
    |> Enum.map(fn absolute ->
      %{
        relative: Path.relative_to(absolute, source_dir),
        digest: file_digest(absolute),
        bytes: File.stat!(absolute).size
      }
    end)
  end

  # A file "differs" only when the target HAS a counterpart whose bytes
  # differ; an absent target (fresh install) differs nowhere -- the cut is
  # justified by `target_exists?`, not by a phantom diff.
  defp differing_files(files, target_dir) do
    for %{relative: relative, digest: digest} <- files,
        existing = file_digest(Path.join(target_dir, relative)),
        existing != :missing,
        existing != digest do
      relative
    end
  end

  defp file_digest(path) do
    case File.read(path) do
      {:ok, body} -> "sha256:" <> Base.encode16(:crypto.hash(:sha256, body), case: :lower)
      {:error, _} -> :missing
    end
  end

  defp stage_and_swap(planned) do
    File.mkdir_p!(planned.cache_root)
    staging = Path.join(planned.cache_root, ".redeploy-staging-#{System.unique_integer()}")

    File.rm_rf!(staging)

    with :ok <- stage(planned.source_dir, staging),
         :ok <- verify_staged(staging, planned.files),
         :ok <- swap(staging, planned.target_dir),
         :ok <- write_receipt(planned) do
      {:ok,
       %{
         version: planned.version,
         target_dir: planned.target_dir,
         file_count: planned.file_count,
         total_bytes: planned.total_bytes,
         receipt: Path.join(planned.target_dir, @receipt_relpath),
         cut_at: DateTime.utc_now(),
         digests: Map.new(planned.files, &{&1.relative, &1.digest})
       }}
    else
      {:error, _reason} = refused ->
        # The staging tree is garbage on any refusal; the target is untouched.
        File.rm_rf!(staging)
        refused
    end
  end

  defp stage(source_dir, staging) do
    case File.cp_r(source_dir, staging) do
      {:ok, _entries} -> :ok
      {:error, reason, _path} -> {:error, {:refused_redeploy, {:stage_failed, reason}}}
    end
  end

  defp verify_staged(staging, files) do
    Enum.find_value(files, :ok, fn %{relative: relative, digest: digest} ->
      staged = file_digest(Path.join(staging, relative))

      if staged == digest,
        do: nil,
        else: {:error, {:refused_redeploy, {:staged_digest_mismatch, relative}}}
    end)
  end

  defp swap(staging, target_dir) do
    File.rm_rf!(target_dir)

    case File.rename(staging, target_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, {:refused_redeploy, {:swap_failed, reason}}}
    end
  end

  defp write_receipt(planned) do
    receipt = %{
      "version" => planned.version,
      "source_dir" => planned.source_dir,
      "target_dir" => planned.target_dir,
      "file_count" => planned.file_count,
      "total_bytes" => planned.total_bytes,
      "cut_at" => DateTime.to_iso8601(DateTime.utc_now()),
      "digests" => Map.new(planned.files, &{&1.relative, &1.digest})
    }

    case File.write(Path.join(planned.target_dir, @receipt_relpath), Jason.encode!(receipt)) do
      :ok -> :ok
      {:error, reason} -> {:error, {:refused_redeploy, {:receipt_failed, reason}}}
    end
  end
end
