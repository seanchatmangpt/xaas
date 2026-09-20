defmodule Xaas.Ultracode.WavePlan do
  @moduledoc """
  The multi-repo planning law for one ultracode wave: WHICH registered
  repositories the wave draws from, and in what order its items are drawn
  across them.

  Three pure functions, no I/O, no clocks -- the same registry state always
  yields the same plan (determinism is a property of this module, tested
  directly):

    * `resolve/2` -- turn a repo SPEC into a sorted list of registered
      aliases. A spec is one alias (`"aps"`), a comma-separated list
      (`"alpha,beta"`), or `"all"` (every registered alias, sorted).
      Unknown aliases and empty selections are typed refusals, never
      guesses at wave time.

    * `rotate/3` -- the per-wave draw. Sensed items are grouped by repo,
      each repo's ready items are truncated to its optional per-repo cap,
      then items are drawn round-robin over the repos in sorted alias
      order: one item per repo per round until every queue is empty.

  The rotation law is the no-starvation guarantee: while a repo has ready
  (uncapped) items, it contributes at least one item to every wave -- the
  first `n` items of any plan cover the first `n` repos exactly once each.
  Without the cap a repo with a deep backlog cannot starve a repo with a
  shallow one, and with the cap a single deep repo cannot monopolize the
  wave's capacity either.

  Single-repo waves (`resolve -> ["aps"]`) degenerate exactly: rotation
  over one queue is that queue's own order, untouched.
  """

  @type spec :: String.t()
  @type registry :: %{String.t() => String.t()}
  @type caps :: %{String.t() => non_neg_integer()} | nil

  @doc """
  Parses a repo spec's SHAPE without the registry: `"all"` -> `:all`,
  `"a, b"` -> `["a", "b"]` (trimmed, deduped, sorted). Bad shapes (empty,
  not a string, empty names) are typed refusals. This is the
  admission-time check a long-lived campaign can make; membership against
  the registry is `resolve/2`, a per-wave concern.
  """
  @spec parse_spec(spec()) :: {:ok, :all | [String.t()]} | {:error, {:bad_repo_spec, term()}}
  def parse_spec(spec) when is_binary(spec) do
    cond do
      spec == "all" ->
        {:ok, :all}

      true ->
        # Split WITHOUT the trim option: an empty segment ("a,,b") is a
        # typo-shaped spec and is refused, never silently coerced.
        names = spec |> String.split(",") |> Enum.map(&String.trim/1)

        if names == [] or Enum.any?(names, &(&1 == "")) do
          {:error, {:bad_repo_spec, spec}}
        else
          {:ok, names |> Enum.uniq() |> Enum.sort()}
        end
    end
  end

  def parse_spec(spec), do: {:error, {:bad_repo_spec, spec}}

  @doc """
  Resolves a repo spec against the operator registry
  (`config :xaas, :ultracode_repos`).

      resolve("aps", %{"aps" => path})                  -> {:ok, ["aps"]}
      resolve("beta,aps", %{"aps" => _, "beta" => _})   -> {:ok, ["aps", "beta"]}
      resolve("all", %{"b" => _, "a" => _})             -> {:ok, ["a", "b"]}
      resolve("ghost", %{})                             -> {:error, {:unknown_repo_alias, "ghost"}}
      resolve("all", %{})                               -> {:error, :no_registered_repos}

  The resolved order is ALWAYS sorted alias order (stable, registry-state
  deterministic) regardless of the spec's spelling, so two campaigns given
  `--repo b,a` and `--repo a,b` plan identical waves.
  """
  @spec resolve(spec(), registry()) :: {:ok, [String.t()]} | {:error, term()}
  def resolve(spec, registry) when is_binary(spec) and is_map(registry) do
    case parse_spec(spec) do
      {:ok, :all} -> all_registered(registry)
      {:ok, names} -> registered(names, registry)
      {:error, _} = err -> err
    end
  end

  def resolve(spec, _registry), do: {:error, {:bad_repo_spec, spec}}

  defp all_registered(registry) do
    case registry |> Map.keys() |> Enum.sort() do
      [] -> {:error, :no_registered_repos}
      repos -> {:ok, repos}
    end
  end

  defp registered(names, registry) do
    Enum.reduce_while(names, {:ok, []}, fn name, {:ok, acc} ->
      if Map.has_key?(registry, name),
        do: {:cont, {:ok, [name | acc]}},
        else: {:halt, {:error, {:unknown_repo_alias, name}}}
    end)
    |> case do
      {:ok, repos} -> {:ok, Enum.reverse(repos)}
      {:error, _} = err -> err
    end
  end

  @doc """
  Validates a per-repo cap map: alias -> non-negative integer item cap for
  one wave. `nil`/`%{}` mean uncapped. Any other shape is a typed refusal
  at admission time, not a surprise mid-wave.
  """
  @spec validate_caps(term()) :: {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}
  def validate_caps(nil), do: {:ok, %{}}

  def validate_caps(caps) when is_map(caps) do
    if Enum.all?(caps, fn {k, v} -> is_binary(k) and is_integer(v) and v >= 0 end) do
      {:ok, caps}
    else
      {:error, {:bad_repo_caps, caps}}
    end
  end

  def validate_caps(other), do: {:error, {:bad_repo_caps, other}}

  @doc """
  Draws one wave's items from per-repo sensed backlogs.

    * `sensed` -- `%{"alias" => [item, ...]}` (each item a string-keyed map,
      already in the repo's own deterministic order);
    * `caps` -- optional per-repo item cap (`alias -> non_neg_integer`);
      a repo's items beyond its cap stay in its backlog for a later wave;
    * repos not present in `sensed` (or with no ready items) contribute
      nothing; caps for unknown repos are inert.

  Returns the flat wave plan: round-robin over the sorted repo aliases,
  each item tagged `"repo" => alias`. Deterministic: same inputs, same
  plan, always.
  """
  @spec rotate(%{String.t() => [map()]}, caps()) :: [map()]
  def rotate(sensed, caps \\ %{}) when is_map(sensed) do
    caps = caps || %{}

    queues =
      sensed
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {repo, items} ->
        capped =
          case Map.get(caps, repo) do
            nil -> items
            cap when is_integer(cap) and cap >= 0 -> Enum.take(items, cap)
          end

        {repo, capped}
      end)
      |> Enum.reject(fn {_repo, items} -> items == [] end)

    draw_rounds(queues)
  end

  # One round draws the head of every non-empty queue, in sorted alias
  # order; the next round recurses on the drained queues. The FIRST round
  # is the no-starvation guarantee: every repo with a ready (uncapped)
  # item is drawn exactly once before any repo is drawn twice.
  defp draw_rounds([]), do: []

  defp draw_rounds(queues) do
    round = Enum.map(queues, fn {repo, [item | _]} -> Map.put(item, "repo", repo) end)
    rest = Enum.map(queues, fn {repo, [_ | tail]} -> {repo, tail} end)

    round ++ draw_rounds(Enum.reject(rest, fn {_repo, items} -> items == [] end))
  end
end
