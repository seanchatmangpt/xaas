defmodule Xaas.Ultracode.WorkerEnv do
  @moduledoc """
  The UltraCode worker environment law, compiled from the `worker_env`
  section of the runtime-surface policy DATA
  `priv/ultracode/runtime_surface.json` (schema
  `xaas-ultracode-runtime-surface/v1`).

  A worker process is spawned with an ALLOWLISTED environment built from
  its parent's: only variable NAMES the policy admits cross the boundary.
  Name precedence (first match wins):

    1. `model_provider_names` ∪ `port_credential_names` -> admitted (the
       worker's own model credential and the SA2A/MCP port credential are
       the only secrets it may hold);
    2. `deny_names`, `deny_prefixes`, `deny_suffix_regex` -> refused (forge,
       cloud, tracker and chat credentials never reach an agent: every
       consequential edge goes UltraCode -> SA2A -> capability);
    3. `allow_names`, `allow_prefixes` -> admitted (local construction
       toolchain);
    4. anything else -> refused.

  Additions supplied by the spawning caller override parent values but are
  filtered by the SAME law, so a caller cannot smuggle `GITHUB_TOKEN` in via
  additions. Receipts carry `key_names/1` and `dropped/2` -- names only,
  never values.

  This module reads the JSON itself (its own `@external_resource`) and does
  not depend on `Xaas.Ultracode.RuntimeSurface`; a malformed `worker_env`
  section fails the build.
  """

  @policy_path Path.expand("../../../priv/ultracode/runtime_surface.json", __DIR__)
  @external_resource @policy_path

  @schema "xaas-ultracode-runtime-surface/v1"
  @policy @policy_path |> File.read!() |> Jason.decode!()

  unless @policy["schema"] == @schema do
    raise CompileError,
      description: "#{@policy_path}: schema is #{inspect(@policy["schema"])}, not #{@schema}"
  end

  @worker_env @policy["worker_env"] ||
                raise(CompileError, description: "#{@policy_path}: missing worker_env")

  list! = fn key ->
    case Map.get(@worker_env, key, []) do
      l when is_list(l) ->
        if Enum.all?(l, &is_binary/1),
          do: l,
          else: raise(CompileError, description: "worker_env.#{key} must be strings")

      other ->
        raise CompileError, description: "worker_env.#{key} is #{inspect(other)}, not a list"
    end
  end

  @grant_names MapSet.new(list!.("model_provider_names") ++ list!.("port_credential_names"))
  @deny_names MapSet.new(list!.("deny_names"))
  @deny_prefixes list!.("deny_prefixes")
  @allow_names MapSet.new(list!.("allow_names"))
  @allow_prefixes list!.("allow_prefixes")
  @deny_suffix_source Map.get(@worker_env, "deny_suffix_regex")

  if @deny_suffix_source != nil and not match?({:ok, _}, Regex.compile(@deny_suffix_source)) do
    raise CompileError,
      description:
        "worker_env.deny_suffix_regex does not compile: #{inspect(@deny_suffix_source)}"
  end

  @typedoc "An environment variable pair."
  @type pair :: {String.t(), String.t()}

  @doc "Absolute path of the policy file this law was compiled from."
  @spec policy_path() :: String.t()
  def policy_path, do: @policy_path

  @doc """
  Whether the variable `name` may cross into a worker environment.

      iex> Xaas.Ultracode.WorkerEnv.allowed?("PATH")
      true
      iex> Xaas.Ultracode.WorkerEnv.allowed?("GITHUB_TOKEN")
      false
  """
  @spec allowed?(String.t()) :: boolean()
  def allowed?(name) when is_binary(name) do
    cond do
      MapSet.member?(@grant_names, name) -> true
      denied?(name) -> false
      MapSet.member?(@allow_names, name) -> true
      Enum.any?(@allow_prefixes, &String.starts_with?(name, &1)) -> true
      true -> false
    end
  end

  def allowed?(_), do: false

  defp denied?(name) do
    MapSet.member?(@deny_names, name) or
      Enum.any?(@deny_prefixes, &String.starts_with?(name, &1)) or
      deny_suffix?(name)
  end

  defp deny_suffix?(name) do
    case @deny_suffix_source do
      nil -> false
      source -> Regex.match?(Regex.compile!(source), name)
    end
  end

  @doc """
  Build the worker environment: `parent_env` filtered by `allowed?/1`, then
  `additions` (also filtered) override. Returns a list sorted by name.
  """
  @spec build(map(), [pair()] | map()) :: [pair()]
  def build(parent_env, additions \\ []) when is_map(parent_env) do
    parent_env
    |> Enum.filter(fn {k, _} -> allowed?(to_string(k)) end)
    |> Map.new(fn {k, v} -> {to_string(k), to_string(v)} end)
    |> Map.merge(
      additions
      |> Enum.filter(fn {k, _} -> allowed?(to_string(k)) end)
      |> Map.new(fn {k, v} -> {to_string(k), to_string(v)} end)
    )
    |> Enum.sort()
  end

  @doc """
  The argv prefix for `/usr/bin/env` that starts the child from an EMPTY
  environment (`-i`) populated only with `pairs`.
  """
  @spec env_argv([pair()]) :: [String.t()]
  def env_argv(pairs), do: ["-i" | Enum.map(pairs, fn {k, v} -> "#{k}=#{v}" end)]

  @doc "Variable names only (for receipts); never values."
  @spec key_names([pair()]) :: [String.t()]
  def key_names(pairs), do: pairs |> Enum.map(fn {k, _} -> to_string(k) end) |> Enum.sort()

  @doc "Names removed from `parent_env` ∪ `additions` by the law (evidence; names only)."
  @spec dropped(map(), [pair()] | map()) :: [String.t()]
  def dropped(parent_env, additions \\ []) when is_map(parent_env) do
    (Enum.map(parent_env, fn {k, _} -> to_string(k) end) ++
       Enum.map(additions, fn {k, _} -> to_string(k) end))
    |> Enum.uniq()
    |> Enum.reject(&allowed?/1)
    |> Enum.sort()
  end
end
