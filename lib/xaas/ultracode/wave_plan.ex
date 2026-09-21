defmodule Xaas.Ultracode.WavePlan do
  @moduledoc """
  The multi-repo wave plan law: WHICH repositories one wave works, and in
  what ORDER its items are dispatched (`docs/ultracode/multi-repo-run.md`
  §3). The plan is a pure function of (spec, registry, sensed items, caps):
  no clocks, no randomness, no I/O beyond the registry read.

  ## Spec (the repo SPEC)

      "aps"                one alias -- byte-for-byte the historical behavior
      "aps,nounverb,eds"   explicit comma list
      "all"                every REGISTERED alias, resolved at wave time

  `parse_spec/1` validates SPEC SHAPE (typed refusals, before any campaign
  row exists); `resolve/1` resolves registry MEMBERSHIP (per wave, so `all`
  picks up later registrations; unknown aliases and an empty registry are
  typed refusals).

  ## Rotation (the no-starvation law)

  Each wave's items are drawn ROUND-ROBIN over the selected repos in sorted
  alias order -- one item per repo per round until queues drain. The first n
  items of any plan therefore cover the first n repos exactly once each: a
  deep backlog can never starve a shallow one.

  ## Per-repo caps

  `config :xaas, :ultracode_wave_repo_caps` (map `alias -> non_neg_integer`,
  e.g. `%{"aps" => 3, "eds" => 1}`): a repo's items beyond its cap stay in
  its backlog for a later wave -- one deep repo cannot monopolize the wave
  either. Caps are validated at admission (`validate_caps/2`); a cap naming
  an alias outside the resolved spec is a typed refusal, never silently dead
  config. Capacity semantics are UNCHANGED: the wave's TOTAL in-flight
  worker bound stays the one semaphore the Autonomic loop already enforces;
  per-repo in-flight accounting is a validation concern
  (`mix xaas.run_validate --per-repo-capacity`), not a second dispatcher.
  """

  alias Xaas.Ultracode.Repos

  @name_format ~r/^[a-z][a-z0-9_-]{0,31}$/

  @typedoc "A validated repo SPEC: `:all`, or the ordered unique alias list."
  @type spec :: :all | [String.t()]

  @doc """
  Parses and shape-validates a repo SPEC: a single alias, a comma list, or
  `all`. Order is preserved (rotation re-sorts later); duplicates are
  collapsed; any empty segment or malformed alias is a typed refusal.
  """
  @spec parse_spec(term()) :: {:ok, spec()} | {:error, term()}
  def parse_spec("all"), do: {:ok, :all}

  def parse_spec(spec) when is_binary(spec) do
    segments = String.split(spec, ",")

    if Enum.any?(segments, &(String.trim(&1) == "")) do
      {:error, {:bad_repo_spec, spec}}
    else
      aliases = segments |> Enum.map(&String.trim/1) |> Enum.uniq()

      case Enum.reject(aliases, &name?/1) do
        [] -> {:ok, aliases}
        bad -> {:error, {:bad_repo_spec, hd(bad)}}
      end
    end
  end

  def parse_spec(spec), do: {:error, {:bad_repo_spec, spec}}

  @doc """
  Resolves registry MEMBERSHIP for a parsed spec: `all` -> every validated
  registered alias (sorted); a list -> each alias resolved against the
  registry (sorted). Unknown aliases and an empty registry are typed
  refusals; membership is resolved PER CALL, so `all` picks up
  registrations added after the spec was written.
  """
  @spec resolve(spec()) :: {:ok, [String.t()]} | {:error, term()}
  def resolve(:all) do
    {entries, _warnings} = Repos.entries()

    aliases =
      entries
      |> Enum.filter(fn {_alias, result} -> match?({:ok, _}, result) end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    if aliases == [] do
      {:error, :no_registered_repos}
    else
      {:ok, aliases}
    end
  end

  def resolve(aliases) when is_list(aliases) do
    case Enum.find(aliases, &(not match?({:ok, _}, Repos.resolve(&1)))) do
      nil -> {:ok, Enum.sort(aliases)}
      alias -> {:error, {:unknown_repo_alias, alias}}
    end
  end

  @doc """
  Validates the per-repo cap config at admission: a map of known-alias keys
  to non-negative integers, where every key is inside the resolved spec
  (otherwise the cap is dead config -- refused, never silently ignored).
  """
  @spec validate_caps(term(), [String.t()]) :: :ok | {:error, term()}
  def validate_caps(caps, aliases) when is_map(caps) and is_list(aliases) do
    shape_result =
      Enum.find_value(caps, :ok, fn
        {alias, cap} when is_binary(alias) and is_integer(cap) and cap >= 0 ->
          if name?(alias), do: :ok, else: {:error, {:bad_repo_spec, alias}}

        other ->
          {:error, {:bad_repo_cap, other}}
      end)

    with :ok <- shape_result,
         [] <- Enum.reject(Map.keys(caps), &(&1 in aliases)) do
      :ok
    else
      {:error, _} = err -> err
      [extra | _] -> {:error, {:unknown_repo_alias, extra}}
    end
  end

  def validate_caps(_caps, _aliases), do: {:error, :bad_repo_caps}

  @doc """
  Reads the operator's per-repo caps from
  `config :xaas, :ultracode_wave_repo_caps` (default: none). Shape is NOT
  re-validated here -- admission (`validate_caps/2`) owns that judgment;
  this is the read the wave loop uses.
  """
  @spec caps() :: map()
  def caps do
    Application.get_env(:xaas, :ultracode_wave_repo_caps, %{})
  end

  @doc """
  The rotation law: round-robin over the repos in SORTED alias order, one
  item per repo per round until queues drain. `items_by_repo` maps alias ->
  sensed items (each already deterministically ordered by its source); each
  repo's list is first truncated to its cap (default: uncapped) -- items
  beyond the cap stay in that repo's backlog for a later wave. Aliases with
  empty or missing queues simply contribute nothing to their rounds.
  """
  @spec rotate(map(), map()) :: [map()]
  def rotate(items_by_repo, caps \\ %{}) when is_map(items_by_repo) and is_map(caps) do
    items_by_repo
    |> Enum.map(fn {alias, items} ->
      cap = Map.get(caps, alias)

      capped =
        if is_integer(cap) and cap >= 0 do
          Enum.take(items, cap)
        else
          items
        end

      {to_string(alias), capped}
    end)
    |> Enum.sort_by(fn {alias, _} -> alias end)
    |> round_robin([])
  end

  defp round_robin(queues, acc) do
    case Enum.reject(queues, fn {_alias, items} -> items == [] end) do
      [] ->
        Enum.reverse(acc)

      live ->
        {heads, tails} =
          live
          |> Enum.map(fn {alias, items} -> {hd(items), {alias, tl(items)}} end)
          |> Enum.unzip()

        round_robin(tails, Enum.reverse(heads) ++ acc)
    end
  end

  defp name?(value) when is_binary(value), do: Regex.match?(@name_format, value)
  defp name?(_), do: false
end
