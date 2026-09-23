defmodule Xaas.Ultracode.NoLlmPolicy do
  @moduledoc """
  The fail-closed no-LLM environment law (GC-26.9.23 GC23-5; PRD PR-009;
  ARD F3; lane R1-X-GUARD), compiled from the policy DATA
  `priv/no_llm/policy.json` -- the same file
  `docs/sjira/v26.9.23/courts/no_llm_env.sh` builds the court environment
  from, so the builder and the guard cannot disagree.

  Admission is an ALLOWLIST: an environment is admitted only when every
  variable NAME is one of the policy's `environment` names (the builder's
  HOME/PATH, durable toolchain configuration, the local test database, the
  court's TMPDIR, what the toolchain launcher chain sets inside the process,
  and what the drive sets for its own children). Anything else is refused:

    * `REFUSED(llm_credential_present)` when a variable is claimed by a
      provider of the policy's `providers` vocabulary (prefix or exact
      name), or when an executable named by a provider's `binaries` sits in
      any `PATH` directory;
    * otherwise `REFUSED(unadmitted_environment)` -- a name no provider
      claims is still refused (the provider list reports WHICH provider
      leaked; it is not the admission rule).

  Both refusals carry broken term `mu_on_O`. Only variable NAMES and binary
  paths are reported, never values.

  The data is read at compile time (`@external_resource`); a malformed
  policy -- an unknown origin, a bad name, an admitted name some provider
  claims, a duplicate provider id -- fails the build.
  """

  @policy_path Path.expand("../../../priv/no_llm/policy.json", __DIR__)
  @external_resource @policy_path

  @policy @policy_path |> File.read!() |> Jason.decode!()

  @schema "xaas/no-llm-policy/v1"
  @origins ~w(builder caller_or_default caller_if_set court_assignment launcher drive)
  @name ~r/^[A-Za-z_][A-Za-z0-9_]*$/
  @binary ~r/^[a-z0-9][a-z0-9._-]*$/

  @admitted @policy["environment"] |> Enum.map(& &1["name"]) |> Enum.sort()
  @providers @policy["providers"]
  @prefixes @providers |> Enum.flat_map(& &1["prefixes"]) |> Enum.uniq() |> Enum.sort()
  @names @providers |> Enum.flat_map(& &1["names"]) |> Enum.uniq() |> Enum.sort()
  @binaries @providers |> Enum.flat_map(& &1["binaries"]) |> Enum.uniq() |> Enum.sort()

  {claimed_names, claimed_prefixes} = {@names, @prefixes}

  claims? = fn name ->
    name in claimed_names or Enum.any?(claimed_prefixes, &String.starts_with?(name, &1))
  end

  problems =
    [
      @policy["schema"] != @schema && "schema is #{inspect(@policy["schema"])}, not #{@schema}",
      @admitted != Enum.uniq(@admitted) && "duplicate environment names",
      Enum.map(@policy["environment"], fn e ->
        cond do
          e["origin"] not in @origins -> "#{e["name"]}: unknown origin #{inspect(e["origin"])}"
          not Regex.match?(@name, e["name"]) -> "bad environment name #{inspect(e["name"])}"
          claims?.(e["name"]) -> "#{e["name"]} is admitted AND claimed by a provider"
          true -> false
        end
      end),
      Enum.map(@providers, & &1["id"]) != Enum.uniq(Enum.map(@providers, & &1["id"])) &&
        "duplicate provider ids",
      Enum.map(@prefixes ++ @names, &(not Regex.match?(@name, &1) && "bad provider name #{&1}")),
      Enum.map(@binaries, &(not Regex.match?(@binary, &1) && "bad provider binary #{&1}")),
      Enum.map(@providers, fn p ->
        p["prefixes"] ++ p["names"] ++ p["binaries"] == [] && "provider #{p["id"]} claims nothing"
      end)
    ]
    |> List.flatten()
    |> Enum.filter(& &1)

  if problems != [] do
    raise CompileError,
      file: @policy_path,
      description: "malformed no-LLM policy: " <> Enum.join(problems, "; ")
  end

  @doc "The policy data as decoded from `priv/no_llm/policy.json` at compile time."
  @spec policy() :: map()
  def policy, do: @policy

  @doc "The repository path of the policy data this module was compiled from."
  @spec path() :: String.t()
  def path, do: @policy_path

  @doc "Every admitted environment-variable NAME, sorted."
  @spec admitted() :: [String.t()]
  def admitted, do: @admitted

  @doc "The provider vocabulary: `%{\"id\", \"name\", \"prefixes\", \"names\", \"binaries\"}` maps."
  @spec providers() :: [map()]
  def providers, do: @providers

  @doc "Every provider prefix and exact name (the variables reported as model credentials)."
  @spec llm_variables() :: %{prefixes: [String.t()], names: [String.t()]}
  def llm_variables, do: %{prefixes: @prefixes, names: @names}

  @doc "Every provider CLI binary name."
  @spec binaries() :: [String.t()]
  def binaries, do: @binaries

  @doc "The ids of the providers that claim variable `name` (prefix or exact name)."
  @spec providers_of_variable(String.t()) :: [String.t()]
  def providers_of_variable(name) do
    for p <- @providers,
        name in p["names"] or Enum.any?(p["prefixes"], &String.starts_with?(name, &1)),
        do: p["id"]
  end

  @doc "The ids of the providers that ship a CLI binary named `binary`."
  @spec providers_of_binary(String.t()) :: [String.t()]
  def providers_of_binary(binary), do: for(p <- @providers, binary in p["binaries"], do: p["id"])

  @doc """
  Judges `env` (a map of NAME => value). `:ok`, or `{:refused, reason,
  detail}` with `reason` `"llm_credential_present"` or
  `"unadmitted_environment"` and `detail` = `%{"variables" => provider-claimed
  names, "binaries" => provider executables on PATH, "providers" => the ids
  that leaked, "unadmitted" => every other non-admitted name}` (names and
  paths only, sorted).
  """
  @spec judge(map()) :: :ok | {:refused, String.t(), map()}
  def judge(env) when is_map(env) do
    names = env |> Map.keys() |> Enum.reject(&(&1 in @admitted)) |> Enum.sort()
    {variables, unadmitted} = Enum.split_with(names, &(providers_of_variable(&1) != []))
    binaries = binaries_on(Map.get(env, "PATH") || "")

    providers =
      (Enum.flat_map(variables, &providers_of_variable/1) ++
         Enum.flat_map(binaries, &providers_of_binary(Path.basename(&1))))
      |> Enum.uniq()
      |> Enum.sort()

    detail = %{
      "variables" => variables,
      "binaries" => binaries,
      "providers" => providers,
      "unadmitted" => unadmitted
    }

    cond do
      variables != [] or binaries != [] -> {:refused, "llm_credential_present", detail}
      unadmitted != [] -> {:refused, "unadmitted_environment", detail}
      true -> :ok
    end
  end

  @doc """
  The admitted projection of `env`: only the policy's names, with every
  `PATH` directory that holds a provider binary dropped. `judge/1` of the
  result is `:ok` (the environment an in-process caller hands the guard when
  its own process runs under an operator shell).
  """
  @spec admitted_environment(map()) :: map()
  def admitted_environment(env) when is_map(env) do
    env
    |> Map.take(@admitted)
    |> then(fn admitted ->
      case admitted do
        %{"PATH" => path} ->
          clean =
            path
            |> String.split(":", trim: true)
            |> Enum.reject(&(dir_binaries(&1) != []))
            |> Enum.join(":")

          Map.put(admitted, "PATH", clean)

        _ ->
          admitted
      end
    end)
  end

  @doc """
  `System.cmd/3` `:env` entries that UNSET every variable of `env` the
  policy does not admit (default: this process's environment), so no child
  process of the drive inherits a credential or an unadmitted variable even
  when the guard was handed a narrower environment than the process's own.
  """
  @spec unset_unadmitted(map()) :: [{String.t(), nil}]
  def unset_unadmitted(env \\ System.get_env()) when is_map(env) do
    for {name, _value} <- env, name not in @admitted, do: {name, nil}
  end

  defp binaries_on(path) do
    path |> String.split(":", trim: true) |> Enum.flat_map(&dir_binaries/1)
  end

  defp dir_binaries(dir) do
    for binary <- @binaries, file = Path.join(dir, binary), executable?(file), do: file
  end

  defp executable?(file) do
    case File.stat(file) do
      {:ok, %File.Stat{type: :regular, mode: mode}} -> Bitwise.band(mode, 0o111) != 0
      _ -> false
    end
  end
end
