defmodule Xaas.Ultracode.CapitalCensus.Route do
  @moduledoc """
  The route lattice for the Capital Census (GC-26926-CENSUS): the total
  order over which a residual gap is dispatched, capital first.

      Reuse ≺ Compose ≺ Rule ≺ Plan ≺ Constraint ≺ Generate ≺
      SpecializedModel ≺ LLM

  `:llm` is the TOP of the lattice — the irreducible residual — **never
  the default**. The census consumes capital (packs, ontologies, receipts,
  generators, verifiers, machine experience) at the LOWEST applicable
  rung; ZCode/LLM reasoning is admitted only after every lower rung is
  recorded failed/unavailable (`residual_route/1`). This is the routing
  companion to `Xaas.Ultracode.NoLlmPolicy` (which keeps LLM credentials
  out of the loop's environment): `Gap = ∅ ⇒ LLM reasoning = 0`, and a
  non-empty gap reaches `:llm` only as the last rung, never the first.

  * `lattice/0` — the rungs, lowest first.
  * `rank/1` — a rung's 0-based position; unknown routes refuse typed.
  * `compare/2` — the total order (`:lt | :gt | :eq`), lower beats higher.
  * `select/2` — the lowest applicable rung among census candidates.
  * `residual_route/1` — the residual dispatch: `{:ok, :llm}` only when
    every rung below `:llm` is recorded failed; a still-applicable lower
    rung denies the residual (`{:ok, lowest_still_applicable}`); `:llm`
    itself failed ⇒ `{:refused, :no_route}`.
  """

  @lattice [:reuse, :compose, :rule, :plan, :constraint, :generate, :specialized_model, :llm]

  @typedoc "A rung of the route lattice, lowest (most-capital) first."
  @type route :: :reuse | :compose | :rule | :plan | :constraint | :generate | :specialized_model | :llm

  @doc "The route lattice, lowest rung first. `:llm` is the TOP — never the default."
  @spec lattice() :: [route(), ...]
  def lattice, do: @lattice

  @doc """
  The 0-based position of `route` in the lattice. Unknown routes (any
  non-atom or atom outside the lattice) refuse:
  `{:refused, :unknown_route}`.
  """
  @spec rank(term()) :: {:ok, non_neg_integer()} | {:refused, :unknown_route}
  def rank(route) when is_atom(route) and route in @lattice do
    {:ok, Enum.find_index(@lattice, &(&1 == route))}
  end

  def rank(_unknown), do: {:refused, :unknown_route}

  @doc """
  The total order, lower beats higher: `:lt` when `a` is a lower rung than
  `b`, `:gt` for the converse, `:eq` for the same rung. A route outside
  the lattice is a function-clause error — `rank/1` is the typed total
  function for untrusted input.
  """
  @spec compare(route(), route()) :: :lt | :gt | :eq
  def compare(a, b) when a in @lattice and b in @lattice do
    {:ok, rank_a} = rank(a)
    {:ok, rank_b} = rank(b)

    cond do
      rank_a < rank_b -> :lt
      rank_a > rank_b -> :gt
      true -> :eq
    end
  end

  @doc """
  The LOWEST applicable rung among census `candidates`, given the census
  `context`.

    * `candidates` — route atoms, or maps with a `:route` key (a map may
      record its own inapplicability with `applicable: false`).
    * `context` — a map; `context[:failed]` lists rungs the census has
      already recorded failed/unavailable.

  A rung is applicable iff it is a known lattice route, its candidate does
  not mark it inapplicable, and it is not failed in the context. Returns
  `{:ok, lowest_applicable}`; `{:refused, :unknown_route}` when a
  candidate names a route outside the lattice; `{:refused, :no_route}`
  when no candidate is applicable (including an empty candidate list).
  The candidate ORDER never decides — the lattice does (anti-vacuity).
  """
  @spec select([route() | map()], map()) ::
          {:ok, route()} | {:refused, :unknown_route} | {:refused, :no_route}
  def select(candidates, context) when is_list(candidates) and is_map(context) do
    failed = MapSet.new(Map.get(context, :failed, []))
    normalized = Enum.map(candidates, &normalize_candidate/1)

    if Enum.any?(normalized, &match?({:refused, :unknown_route}, &1)) do
      {:refused, :unknown_route}
    else
      applicable =
        Enum.flat_map(normalized, fn
          {route, true} -> [route]
          {_route, false} -> []
        end)
        |> Enum.reject(&MapSet.member?(failed, &1))

      case applicable do
        [] -> {:refused, :no_route}
        applicable -> {:ok, Enum.min_by(applicable, &elem(rank(&1), 1))}
      end
    end
  end

  @doc """
  The residual dispatch — the census's answer to "what does ZCode get?"

  `failed` lists every rung recorded failed/unavailable. The residual gap
  reaches `:llm` ONLY when every rung below it is in `failed` (the
  irreducible residual): `{:ok, :llm}`. If any lower rung still stands,
  the residual was not irreducible and the answer is the LOWEST
  still-applicable rung. `:llm` itself failed/unavailable ⇒
  `{:refused, :no_route}` — no lower rung and no LLM is a typed refusal,
  never a fallback. Unknown rungs refuse `{:refused, :unknown_route}`.
  """
  @spec residual_route([term()]) ::
          {:ok, route()} | {:refused, :no_route} | {:refused, :unknown_route}
  def residual_route(failed) when is_list(failed) do
    cond do
      not Enum.all?(failed, &(&1 in @lattice)) ->
        {:refused, :unknown_route}

      :llm in failed ->
        {:refused, :no_route}

      true ->
        {:ok, Enum.find(@lattice, &(&1 not in failed))}
    end
  end

  defp normalize_candidate(route) when is_atom(route) and route in @lattice, do: {route, true}

  defp normalize_candidate(%{route: route} = candidate)
       when is_atom(route) and route in @lattice do
    {route, Map.get(candidate, :applicable, true) not in [false, nil]}
  end

  defp normalize_candidate(_unknown), do: {:refused, :unknown_route}
end
