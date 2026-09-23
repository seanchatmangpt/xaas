defmodule Xaas.Ultracode.ZcodePackage do
  @moduledoc """
  The zcode CLI's own `package.json` is the contract xaas dispatches against
  (`~/dev/zcode-cli/package.json`: `name` `zcode-app-cli`, `bin.zcode`,
  `engines.node`). Nothing in xaas hard-codes the launcher path or the Node
  floor any more; both are read from that file:

    * `name` must be `zcode-app-cli` (a different package in the CLI dir is a
      typed refusal, not a silent dispatch);
    * the launcher script is `bin.zcode` resolved inside the CLI dir and must
      be a regular file. Containment is checked on REAL paths: a symlink
      under the CLI dir that resolves outside it (`bin/zcode.js ->
      /elsewhere/evil.js`) is refused, while a symlink that stays inside the
      dir is admitted. The shell preflight in
      `scripts/xaas-glm-failover-dispatcher.sh` does the same with
      `fs.realpathSync` on both sides;
    * the Node executable that will run the worker must satisfy
      `engines.node` (only `>=X.Y.Z` floors are understood; any other range
      form is a typed refusal rather than a guess) -- measured by running
      `<node> --version`, never assumed. The probe is bounded: it leads its
      own process group with a SIGALRM backstop and the BEAM-side deadline
      (`:node_version_timeout_ms`, default 5000) kills the whole group, so a
      hung shim (a stalled nvm/asdf/volta wrapper, a stalled mount) yields
      `{:error, {:node_version_unreadable, node, "timeout after Nms"}}`
      instead of blocking the caller forever.

  Pure read + one bounded `--version` subprocess; grants no authority and
  starts no worker.
  """

  alias Xaas.Ultracode.ProcessGroup

  @package_name "zcode-app-cli"
  @floor ~r/\A>=\s*(\d+)\.(\d+)\.(\d+)\z/
  @node_version ~r/\Av(\d+)\.(\d+)\.(\d+)/

  # Same process-group wrapper shape as `Xaas.Ultracode.Verifier` / `Dispatch`:
  # lead a fresh group, arm SIGALRM, exec the argv. The alarm is only the
  # backstop for a BEAM that dies mid-probe; the BEAM-side deadline kills the
  # group first.
  @wrapper "setpgrp(0,0); alarm(shift @ARGV); exec @ARGV or exit 127;"
  @perl "/usr/bin/perl"
  @default_version_timeout_ms 5_000
  @alarm_grace_s 2

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
         version: version(pkg),
         dir: cli_dir,
         bin: bin,
         script: script,
         node_floor: floor
       }}
    end
  end

  def load(_), do: {:error, {:cli_unavailable, "unset"}}

  @doc """
  Does `node_path` (an executable) satisfy the package's `engines.node` floor?
  Options as `verify_node/3`.
  """
  @spec check_node(t(), String.t(), keyword()) :: :ok | {:error, term()}
  def check_node(pkg, node_path, opts \\ []) do
    with {:ok, _found} <- verify_node(pkg, node_path, opts), do: :ok
  end

  @doc """
  Like `check_node/3`, but on success returns the node version that was
  measured (`{major, minor, patch}`), so callers can report it.

  Options: `:node_version_timeout_ms` (default #{@default_version_timeout_ms}) --
  hard deadline for the `--version` probe; on expiry the probe's whole
  process group is killed and the answer is
  `{:error, {:node_version_unreadable, node_path, "timeout after Nms"}}`.
  """
  @spec verify_node(t(), String.t(), keyword()) ::
          {:ok, {non_neg_integer(), non_neg_integer(), non_neg_integer()}} | {:error, term()}
  def verify_node(%{node_floor: floor}, node_path, opts \\ []) when is_binary(node_path) do
    exe = System.find_executable(node_path) || node_path
    timeout_ms = Keyword.get(opts, :node_version_timeout_ms) || @default_version_timeout_ms

    case probe_version(exe, node_path, timeout_ms) do
      {:ok, out} ->
        case Regex.run(@node_version, String.trim(out), capture: :all_but_first) do
          [a, b, c] ->
            found = {String.to_integer(a), String.to_integer(b), String.to_integer(c)}

            if found >= floor,
              do: {:ok, found},
              else: {:error, {:node_too_old, node_path, tuple_s(found), ">=" <> tuple_s(floor)}}

          _ ->
            {:error, {:node_version_unreadable, node_path, String.slice(out, 0, 80)}}
        end

      {:error, _typed} = error ->
        error
    end
  end

  @doc "Render a `{major, minor, patch}` version tuple as `\"X.Y.Z\"`."
  @spec version_string({non_neg_integer(), non_neg_integer(), non_neg_integer()}) :: String.t()
  def version_string(version), do: tuple_s(version)

  @doc "The CLI checkout xaas dispatches against unless `:cli_dir` / app env says otherwise."
  @spec default_cli_dir() :: String.t()
  def default_cli_dir, do: "/Users/sac/dev/zcode-cli"

  @doc "Load the package and check the node in one call (options as `verify_node/3`)."
  @spec check(term(), String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def check(cli_dir, node_path, opts \\ []) do
    with {:ok, pkg} <- load(cli_dir),
         :ok <- check_node(pkg, node_path, opts),
         do: {:ok, pkg}
  end

  @doc "Default `--version` probe deadline in milliseconds."
  @spec default_version_timeout_ms() :: pos_integer()
  def default_version_timeout_ms, do: @default_version_timeout_ms

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

  # QUALIFIER FIX: `t()` promises a String; a non-string package.json version
  # (123, null, object) used to flow through verbatim into ProviderHealth.
  defp version(%{"version" => v}) when is_binary(v) and v != "", do: v
  defp version(_), do: "unknown"

  defp name(%{"name" => @package_name}, _path), do: :ok

  defp name(%{"name" => other}, path),
    do: {:error, {:zcode_package_invalid, path, {:wrong_name, other}}}

  defp name(_, path), do: {:error, {:zcode_package_invalid, path, :missing_name}}

  defp bin(%{"bin" => %{"zcode" => rel}}, _path) when is_binary(rel) and rel != "", do: {:ok, rel}
  defp bin(_, path), do: {:error, {:zcode_package_invalid, path, :missing_bin_zcode}}

  # Containment is decided twice: lexically (`..` / absolute `rel`), then on
  # REAL paths -- both the launcher and the CLI dir are resolved through every
  # symlink before comparing, so `bin/zcode.js -> /outside/evil.js` is refused
  # and an in-dir symlink is not. (Both sides must be resolved: a symlinked
  # ancestor of the CLI dir, e.g. macOS /var -> /private/var, would otherwise
  # make every launcher look like an escape.)
  defp script(cli_dir, rel) do
    root = Path.expand(cli_dir)
    script = Path.expand(rel, root)

    with true <- String.starts_with?(script, root <> "/"),
         {:ok, real_root} <- real_path(root),
         {:ok, real_script} <- real_path(script),
         true <- String.starts_with?(real_script, real_root <> "/"),
         true <- File.regular?(real_script) do
      {:ok, script}
    else
      _ -> {:error, {:cli_unavailable, script}}
    end
  end

  @max_symlink_hops 40

  # Resolve `path` through every symlink component (POSIX realpath, no
  # subprocess, no macOS-only binary). `{:error, :eloop}` after 40 hops
  # (`@max_symlink_hops`); a component that does not exist is kept as-is
  # (the regular-file check that follows decides).
  defp real_path(path, hops \\ 0)
  defp real_path(_path, hops) when hops > @max_symlink_hops, do: {:error, :eloop}

  defp real_path(path, hops) do
    [root | parts] = path |> Path.expand() |> Path.split()
    walk(root, parts, hops)
  end

  defp walk(resolved, [], _hops), do: {:ok, resolved}

  defp walk(resolved, [part | rest], hops) do
    candidate = Path.join(resolved, part)

    case File.read_link(candidate) do
      {:ok, target} ->
        # `resolved` is already real, so a relative target is relative to it.
        real_path(Path.join([Path.expand(target, resolved) | rest]), hops + 1)

      {:error, _not_a_link} ->
        walk(candidate, rest, hops)
    end
  end

  # `<exe> --version` under a deadline, in its own process group. Returns the
  # merged output on exit 0, otherwise a typed error. The group is reaped on
  # EVERY exit path (clean exit, timeout, crash), never left to a hung shim.
  defp probe_version(exe, node_path, timeout_ms) do
    cond do
      not File.exists?(@perl) ->
        {:error, {:node_unavailable, node_path, "perl missing: no bounded --version probe"}}

      not (File.exists?(exe) or is_binary(System.find_executable(exe))) ->
        {:error, {:node_unavailable, node_path, ":enoent"}}

      true ->
        alarm_s = div(timeout_ms + 999, 1000) + @alarm_grace_s

        port =
          Port.open({:spawn_executable, @perl}, [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            :hide,
            {:args, ["-e", @wrapper, Integer.to_string(alarm_s), exe, "--version"]}
          ])

        os_pid =
          case Port.info(port, :os_pid) do
            {:os_pid, pid} -> pid
            _ -> nil
          end

        deadline = System.monotonic_time(:millisecond) + timeout_ms

        try do
          collect(port, deadline, "", node_path, timeout_ms)
        after
          if os_pid, do: ProcessGroup.kill(os_pid)

          try do
            Port.close(port)
          rescue
            ArgumentError -> :ok
          end
        end
    end
  rescue
    error in ErlangError -> {:error, {:node_unavailable, node_path, inspect(error.original)}}
  end

  defp collect(port, deadline, acc, node_path, timeout_ms) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^port, {:data, data}} ->
        collect(port, deadline, acc <> data, node_path, timeout_ms)

      {^port, {:exit_status, 0}} ->
        {:ok, acc}

      {^port, {:exit_status, status}} ->
        {:error,
         {:node_version_unreadable, node_path, "exit #{status}: " <> String.slice(acc, 0, 80)}}
    after
      remaining ->
        {:error, {:node_version_unreadable, node_path, "timeout after #{timeout_ms}ms"}}
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
