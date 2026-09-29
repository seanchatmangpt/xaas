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
    2. `deny_names`, `deny_prefixes`, `deny_word_regex` (secret words anywhere
       in the name) -> refused; any name not matching `name_regex` is refused first (forge,
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
  @deny_word_source Map.fetch!(@worker_env, "deny_word_regex")
  @name_source Map.fetch!(@worker_env, "name_regex")
  @url_names MapSet.new(Map.get(@worker_env, "url_names_no_userinfo", []))
  @credential_value_source Map.fetch!(@worker_env, "credential_value_regex")
  @secret_value_source Map.fetch!(@worker_env, "secret_value_regex")

  for {key, source} <- [
        deny_word_regex: @deny_word_source,
        name_regex: @name_source,
        credential_value_regex: @credential_value_source,
        secret_value_regex: @secret_value_source
      ],
      not match?({:ok, _}, Regex.compile(source)) do
    raise CompileError,
      description: "worker_env.#{key} does not compile: #{inspect(source)}"
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
      # Only canonical POSIX-uppercase names cross: lowercase, mixed case,
      # whitespace and zero-width variants of a secret name never reach the
      # deny rules' blind spots because they never reach the child at all.
      not Regex.match?(Regex.compile!(@name_source), name) -> false
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
      Regex.match?(Regex.compile!(@deny_word_source), name)
  end

  # A URL-valued variable (model endpoint, port endpoint) may cross only
  # without embedded userinfo: `https://user:pass@host` would smuggle a
  # credential through an admitted name.
  # Court env3: an admitted NAME is no guarantee about its VALUE
  # (`ZCODE_OCEL=sk-ant-...`, `TERM=xterm;https://u:p@h`). Every value is
  # checked for credential shapes, except the explicitly granted model/port
  # credentials, whose values are credentials by definition.
  defp value_admitted?(name, value) do
    (MapSet.member?(@grant_names, name) or
       (not Regex.match?(Regex.compile!(@credential_value_source), value) and
          not Regex.match?(Regex.compile!(@secret_value_source), value))) and
      (not MapSet.member?(@url_names, name) or plain_http_url?(value))
  end

  # Court env2 F1/F2: Elixir's URI and Node's WHATWG URL disagree on inputs
  # like `https:u:pw@h`, so a URL-valued name must be an unambiguous
  # http(s) URL with a host, no `@` anywhere, and no query/fragment.
  defp plain_http_url?(value) do
    not String.contains?(value, "@") and
      match?(
        {:ok, %URI{scheme: scheme, host: host, userinfo: nil, query: nil, fragment: nil}}
        when scheme in ["http", "https"] and is_binary(host) and host != "",
        URI.new(value)
      )
  end

  defp admitted_pair?({k, v}),
    do: allowed?(to_string(k)) and value_admitted?(to_string(k), to_string(v))

  # An EXPLICIT caller assignment (dispatch `:extra_env`, a repo
  # `toolchain_env` pin) is named intent, not ambient inheritance: it may
  # carry a name the allowlist does not enumerate, but never a denied one.
  defp explicit_pair?({k, v}) do
    name = to_string(k)

    Regex.match?(Regex.compile!(@name_source), name) and
      (MapSet.member?(@grant_names, name) or not denied?(name)) and
      value_admitted?(name, to_string(v))
  end

  @doc """
  `build/2`, plus `explicit` caller assignments that may name variables the
  allowlist does not enumerate (test harness scripting, repo toolchain pins)
  but still pass every deny rule. Explicit pairs win on conflict.
  """
  @spec build(map(), [pair()] | map(), [pair()] | map()) :: [pair()]
  def build(parent_env, additions, explicit) when is_map(parent_env) do
    parent_env
    |> build(additions)
    |> Map.new()
    |> Map.merge(
      explicit
      |> Enum.filter(&explicit_pair?/1)
      |> Map.new(fn {k, v} -> {to_string(k), to_string(v)} end)
    )
    |> Enum.sort()
  end

  @doc """
  Build the worker environment: `parent_env` filtered by `allowed?/1`, then
  `additions` (also filtered) override. Returns a list sorted by name.
  """
  @spec build(map(), [pair()] | map()) :: [pair()]
  def build(parent_env, additions \\ []) when is_map(parent_env) do
    parent_env
    |> Enum.filter(&admitted_pair?/1)
    |> Map.new(fn {k, v} -> {to_string(k), to_string(v)} end)
    |> Map.merge(
      additions
      |> Enum.filter(&admitted_pair?/1)
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
    (Enum.to_list(parent_env) ++ Enum.to_list(additions))
    |> Enum.reject(&admitted_pair?/1)
    |> Enum.map(fn {k, _} -> to_string(k) end)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
