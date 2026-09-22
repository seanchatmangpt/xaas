defmodule Xaas.Ultracode.ZcodePackage do
  @moduledoc """
  The zcode CLI's own `package.json` is the contract xaas dispatches against
  (`~/dev/zcode-cli/package.json`: `name` `zcode-app-cli`, `bin.zcode`,
  `engines.node`). Nothing in xaas hard-codes the launcher path or the Node
  floor any more; both are read from that file:

    * `name` must be `zcode-app-cli` (a different package in the CLI dir is a
      typed refusal, not a silent dispatch);
    * the launcher script is `bin.zcode` resolved inside the CLI dir (it may
      not escape it) and must be a regular file;
    * the Node executable that will run the worker must satisfy
      `engines.node` (only `>=X.Y.Z` floors are understood; any other range
      form is a typed refusal rather than a guess) -- measured by running
      `<node> --version`, never assumed.

  Pure read + one `--version` subprocess; grants no authority and starts no
  worker.
  """

  @package_name "zcode-app-cli"
  @floor ~r/\A>=\s*(\d+)\.(\d+)\.(\d+)\z/
  @node_version ~r/\Av(\d+)\.(\d+)\.(\d+)/

  @type t :: %{
          name: String.t(),
          version: String.t(),
          dir: String.t(),
          bin: String.t(),
          script: String.t(),
          node_floor: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
        }

  @spec package_name() :: String.t()
  def package_name, do: @package_name

  @doc "Read and admit `<cli_dir>/package.json`."
  @spec load(term()) :: {:ok, t()} | {:error, term()}
  def load(cli_dir) when is_binary(cli_dir) do
    path = Path.join(cli_dir, "package.json")

    with {:ok, raw} <- read(path),
         {:ok, pkg} <- decode(raw, path),
         :ok <- name(pkg, path),
         {:ok, bin} <- bin(pkg, path),
         {:ok, script} <- script(cli_dir, bin),
         {:ok, floor} <- node_floor(pkg, path) do
      {:ok,
       %{
         name: pkg["name"],
         version: Map.get(pkg, "version", "unknown"),
         dir: cli_dir,
         bin: bin,
         script: script,
         node_floor: floor
       }}
    end
  end

  def load(_), do: {:error, {:cli_unavailable, "unset"}}

  @doc "Does `node_path` (an executable) satisfy the package's `engines.node` floor?"
  @spec check_node(t(), String.t()) :: :ok | {:error, term()}
  def check_node(pkg, node_path) do
    with {:ok, _found} <- verify_node(pkg, node_path), do: :ok
  end

  @doc """
  Like `check_node/2`, but on success returns the node version that was
  measured (`{major, minor, patch}`), so callers can report it.
  """
  @spec verify_node(t(), String.t()) ::
          {:ok, {non_neg_integer(), non_neg_integer(), non_neg_integer()}} | {:error, term()}
  def verify_node(%{node_floor: floor}, node_path) when is_binary(node_path) do
    exe = System.find_executable(node_path) || node_path

    case System.cmd(exe, ["--version"], stderr_to_stdout: true) do
      {out, 0} ->
        case Regex.run(@node_version, String.trim(out), capture: :all_but_first) do
          [a, b, c] ->
            found = {String.to_integer(a), String.to_integer(b), String.to_integer(c)}

            if found >= floor,
              do: {:ok, found},
              else: {:error, {:node_too_old, node_path, tuple_s(found), ">=" <> tuple_s(floor)}}

          _ ->
            {:error, {:node_version_unreadable, node_path, String.slice(out, 0, 80)}}
        end

      {out, status} ->
        {:error,
         {:node_version_unreadable, node_path, "exit #{status}: " <> String.slice(out, 0, 80)}}
    end
  rescue
    error in ErlangError -> {:error, {:node_unavailable, node_path, inspect(error.original)}}
  end

  @doc "Render a `{major, minor, patch}` version tuple as `\"X.Y.Z\"`."
  @spec version_string({non_neg_integer(), non_neg_integer(), non_neg_integer()}) :: String.t()
  def version_string(version), do: tuple_s(version)

  @doc "The CLI checkout xaas dispatches against unless `:cli_dir` / app env says otherwise."
  @spec default_cli_dir() :: String.t()
  def default_cli_dir, do: "/Users/sac/dev/zcode-cli"

  @doc "Load the package and check the node in one call."
  @spec check(term(), String.t()) :: {:ok, t()} | {:error, term()}
  def check(cli_dir, node_path) do
    with {:ok, pkg} <- load(cli_dir), :ok <- check_node(pkg, node_path), do: {:ok, pkg}
  end

  defp tuple_s({a, b, c}), do: "#{a}.#{b}.#{c}"

  defp read(path) do
    case File.read(path) do
      {:ok, raw} -> {:ok, raw}
      {:error, _} -> {:error, {:cli_unavailable, path}}
    end
  end

  defp decode(raw, path) do
    case Jason.decode(raw) do
      {:ok, %{} = pkg} -> {:ok, pkg}
      _ -> {:error, {:zcode_package_invalid, path, :not_json_object}}
    end
  end

  defp name(%{"name" => @package_name}, _path), do: :ok

  defp name(%{"name" => other}, path),
    do: {:error, {:zcode_package_invalid, path, {:wrong_name, other}}}

  defp name(_, path), do: {:error, {:zcode_package_invalid, path, :missing_name}}

  defp bin(%{"bin" => %{"zcode" => rel}}, _path) when is_binary(rel) and rel != "", do: {:ok, rel}
  defp bin(_, path), do: {:error, {:zcode_package_invalid, path, :missing_bin_zcode}}

  defp script(cli_dir, rel) do
    root = Path.expand(cli_dir)
    script = Path.expand(rel, root)

    cond do
      not String.starts_with?(script, root <> "/") -> {:error, {:cli_unavailable, script}}
      not File.regular?(script) -> {:error, {:cli_unavailable, script}}
      true -> {:ok, script}
    end
  end

  defp node_floor(%{"engines" => %{"node" => range}}, path) when is_binary(range) do
    case Regex.run(@floor, String.trim(range), capture: :all_but_first) do
      [a, b, c] -> {:ok, {String.to_integer(a), String.to_integer(b), String.to_integer(c)}}
      _ -> {:error, {:zcode_package_invalid, path, {:unsupported_engines_range, range}}}
    end
  end

  defp node_floor(_, path), do: {:error, {:zcode_package_invalid, path, :missing_engines_node}}
end
