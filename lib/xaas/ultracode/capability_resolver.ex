defmodule Xaas.Ultracode.CapabilityResolver do
  # Bound BEFORE the moduledoc, which interpolates it. The bounded greedy
  # composition: never more than this many capabilities compose one item.
  @max_composition 4

  @moduledoc """
  The mandatory capability-resolution court between sensing and coding in
  the Ultracode loop. After `Autonomic.run/1` senses a wave's items, every
  item passes THROUGH this court before it can reach a coding worker: an
  item is classed `:frontier` (worker-eligible) ONLY when the court has
  PROVEN that no capability the fleet already holds -- and no lawful
  composition of such capabilities -- satisfies the item's requirements.

  ## The invariant (encoded, test-guarded)

      FRONTIER(w)  <=>  ¬∃ c ∈ Closure(C_fleet) : c ⊨ requirements(w)

  `test/xaas/ultracode/capability_resolver_test.exs` guards both arrows:
  a `:frontier` class only after zero candidates satisfy the item (the
  anti-vacuity mutation test: injecting ONE satisfying capability into a
  source flips the same item to `:reuse`), and never on a source error or
  a skipped witness.

  ## Mechanical matching, v1 (NO LLM)

  This is an ADMISSION court, not a planner: the predicate is mechanical
  only, so the same items + sources replay to the same verdict.

    * an item's `requirements/1` are its declared requirement ids:
      `item["capability_id"]` (the `sj:requiresCapability` shape `Run`
      already carries) and/or the `item["required_capabilities"]` list;
    * a capability `covers` a requirement iff the requirement id is in the
      capability's `satisfies` list or equals its `capability_id`;
    * a capability `satisfies` an item iff it covers EVERY declared
      requirement. An item declaring NO requirement ids is classed
      `:frontier` -- the court cannot NAME a capability that witnesses it,
      so no closure entry satisfies it (this is also what keeps today's
      requirement-less backlog items flowing to workers unchanged).

  ## Classes

    * `:reuse` -- one existing capability satisfies every requirement;
    * `:compose` -- a bounded (<= #{@max_composition}-member, greedy,
      deterministic) composition covers every requirement;
    * `:extend` -- candidates cover SOME requirements; the residual names
      what an extension of the existing family must add;
    * `:generate` -- no coverage, but a candidate shares a capability
      family (the `namespace:` prefix) with a requirement;
    * `:frontier` -- proven new work; the ONLY class that reaches a
      coding worker;
    * `:unresolved` -- the court refused to decide (fail-closed law
      below). BLOCKED: no epoch, no worker.

  ## Fail-closed law

  For an item WITH declared requirements: `:frontier` (and every satisfied
  class) requires that at least one configured source returned `{:ok, _}`
  AND, under full-closure mode (default ON), that NO configured source
  returned `{:skipped, _}`, AND that no source returned `{:error, _}`.
  Any `{:error, _}` anywhere => `:unresolved` (the court cannot claim to
  have seen the whole closure). Any `{:skipped, _}` under full-closure =>
  `:unresolved`. An operator may run reduced-closure mode
  (`ctx[:capability_full_closure] == false`) to let `:ok` sources drive a
  verdict past a skipped witness. Zero configured sources => `:unresolved`
  (a court with no witnesses is vacuous, and a vacuous court proves
  nothing).

  An item declaring NO requirement ids is OUTSIDE this law by scope, not
  exception: no closure entry can cover an unnamed requirement WHATEVER
  the sources hold, so its verdict is source-independent and the court
  queries nothing (a check with no consumer carries no bits). Such items
  are `:frontier` by construction -- which is what keeps today's
  requirement-less backlog waves flowing unchanged with the court ON.

  ## Sources

  Configured under `config :xaas, :ultracode_capability_sources` (name =>
  module implementing `Xaas.Ultracode.CapabilityResolver.Source`). Default:
  the in-repo `Local` census/run-history source and the config-driven
  `Sa2a` cross-fleet HTTP source (skipped when unset). Candidates are
  re-admitted by the court through `Source.admit_candidates/2`; one
  invalid candidate fails its whole source call (fail-closed), because a
  silently dropped candidate might have been the satisfier.

  Every verdict is sealed as a `CapabilityResolver.Receipt` (candidate
  capabilities with their sources, selection, class, residual, per-source
  status, and the standing falsifier), persisted BEFORE the dispatch
  stage -- no worker can claim an item whose resolution receipt is not
  already on disk.
  """

  alias Xaas.Ultracode.CapabilityResolver.{Receipt, Source}
  alias Xaas.Ultracode.SemanticWork

  @default_sources %{
    "local" => Xaas.Ultracode.CapabilityResolver.Source.Local,
    "sa2a" => Xaas.Ultracode.CapabilityResolver.Source.Sa2a
  }

  @doc """
  Resolves every item against the fleet's capability closure, in input
  order: one `CapabilityResolver.Receipt` per item, whose `class` is the
  court's verdict. Never raises on source failure -- a failing source is
  `:unresolved`, by the fail-closed law.
  """
  @spec resolve_items([map()], map() | keyword()) :: [Receipt.t()]
  def resolve_items(items, ctx) when is_list(items) do
    Enum.map(items, &resolve_item(&1, ctx))
  end

  @doc """
  The court on one item: queries every configured source, re-admits the
  candidates, applies the mechanical predicate, and seals the receipt.
  """
  @spec resolve_item(map(), map() | keyword()) :: Receipt.t()
  def resolve_item(item, ctx) when is_map(item) do
    requirements = requirements(item)

    {statuses, verdict} =
      if requirements == [] do
        # Outside the court's mechanical scope: no closure entry can cover
        # an UNNAMED requirement whatever the sources hold, so the verdict
        # is source-independent -- querying would be a zero-information
        # check. Such items are :frontier by construction, which is also
        # what keeps today's requirement-less backlog waves flowing.
        {%{}, {:decided, :frontier, [], []}}
      else
        statuses = query_sources(configured_sources(), item, ctx)
        {statuses, verdict(requirements, statuses, ctx)}
      end

    receipt =
      case verdict do
        {:decided, class, selected, residual} ->
          Receipt.new(
            item_id: item["id"],
            repo: Map.get(item, "repo"),
            required_capabilities: requirements,
            candidate_capabilities: candidates_from(statuses),
            selected_capabilities: Enum.map(selected, & &1.capability_id),
            class: class,
            residual_requirements: residual,
            sources_queried: statuses
          )

        :unresolved ->
          Receipt.new(
            item_id: item["id"],
            repo: Map.get(item, "repo"),
            required_capabilities: requirements,
            candidate_capabilities: candidates_from(statuses),
            selected_capabilities: [],
            class: :unresolved,
            residual_requirements: requirements,
            sources_queried: statuses
          )
      end

    receipt
  end

  @doc """
  The item's declared requirement ids, mechanically extracted (never
  inferred): the `sj:requiresCapability` shape (`"capability_id"`, or its
  `"capability"` alias) plus the `"required_capabilities"` list, deduped
  and sorted for deterministic verdicts.
  """
  @spec requirements(map()) :: [String.t()]
  def requirements(item) when is_map(item) do
    scalars =
      [Map.get(item, "capability_id"), Map.get(item, "capability")]
      |> Enum.filter(&is_binary/1)
      |> Enum.reject(&(&1 == ""))

    listed =
      case Map.get(item, "required_capabilities") do
        ids when is_list(ids) -> Enum.filter(ids, &is_binary/1)
        id when is_binary(id) and id != "" -> [id]
        _ -> []
      end

    (scalars ++ listed)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Re-admits one source's returned candidates through the court's own
  admission (the source is a witness, never trusted): every candidate
  must be a map with a `capability_id` matching the canonical
  `sj:capabilityId` pattern (byte-identical to
  `SemanticWork.capability_id_pattern/0`) and a non-empty binary
  `satisfies` list. ONE invalid candidate refuses the WHOLE source call.
  """
  @spec admit_candidates(String.t(), term()) :: {:ok, [Source.capability()]} | {:error, term()}
  def admit_candidates(source_name, candidates) when is_list(candidates) do
    Enum.reduce_while(candidates, {:ok, []}, fn candidate, {:ok, acc} ->
      case admit_candidate(candidate) do
        {:ok, admitted} -> {:cont, {:ok, [stamped(admitted, source_name) | acc]}}
        {:error, reason} -> {:halt, {:error, {:invalid_candidate, source_name, candidate, reason}}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  def admit_candidates(source_name, other),
    do: {:error, {:invalid_candidates, source_name, other}}

  # ------------------------------------------------------------------
  # Sources
  # ------------------------------------------------------------------

  defp configured_sources do
    Application.get_env(:xaas, :ultracode_capability_sources, @default_sources) || %{}
  end

  # One source call, crash-isolated: a raising source is a FAILED source
  # (`{:error, {:raised, _}}`), never a crash of the court and never a
  # silently-missing witness.
  defp query_sources(sources, item, ctx) when is_map(sources) do
    Map.new(sources, fn {name, module} ->
      result =
        try do
          module.candidates(item, ctx)
        rescue
          error -> {:error, {:raised, module, Exception.message(error)}}
        end

      admitted =
        case result do
          {:ok, candidates} -> admit_candidates(to_string(name), candidates)
          other -> other
        end

      {to_string(name), status(admitted)}
    end)
  end

  defp status({:ok, candidates}) when is_list(candidates), do: %{status: :ok, detail: candidates}
  defp status({:error, reason}), do: %{status: :error, detail: reason}
  defp status({:skipped, reason}), do: %{status: :skipped, detail: reason}
  # A misbehaving source that returns garbage is a failed source.
  defp status(other), do: %{status: :error, detail: {:invalid_source_result, other}}

  defp admit_candidate(%{} = candidate) do
    with {:ok, id} <- capability_id(candidate),
         {:ok, satisfies} <- satisfies(candidate) do
      {:ok, %{capability_id: id, satisfies: satisfies}}
    end
  end

  defp admit_candidate(_other), do: {:error, :not_a_map}

  defp capability_id(candidate) do
    case candidate do
      %{capability_id: id} when is_binary(id) -> admit_id(id)
      %{"capability_id" => id} when is_binary(id) -> admit_id(id)
      _ -> {:error, :capability_id_missing}
    end
  end

  # Reuses the canonical pattern -- byte-identical source by construction,
  # never a second hand-maintained copy.
  defp admit_id(id), do: if(Regex.match?(SemanticWork.capability_id_pattern(), id), do: {:ok, id}, else: {:error, :capability_id_pattern})

  defp satisfies(candidate) do
    satisfies =
      candidate[:satisfies] || candidate["satisfies"]

    case satisfies do
      ids when is_list(ids) and ids != [] ->
        if Enum.all?(ids, &(is_binary(&1) and &1 != "")),
          do: {:ok, Enum.uniq(ids)},
          else: {:error, :satisfies_not_binary_ids}

      _ ->
        {:error, :satisfies_missing}
    end
  end

  defp stamped(candidate, source_name), do: Map.put(candidate, :source, source_name)

  # ------------------------------------------------------------------
  # Verdict
  # ------------------------------------------------------------------

  # The fleet's answer, as the court admitted it: every candidate from
  # every source that answered `{:ok, _}` (source-stamped, pattern-checked).
  defp candidates_from(statuses) do
    Enum.flat_map(statuses, fn {_, s} -> (s.status == :ok && s.detail) || [] end)
  end

  # The fail-closed law, then the mechanical classification.
  defp verdict(requirements, statuses, ctx) do
    full_closure? = Map.get(ctx, :capability_full_closure, true)

    any_error? = Enum.any?(statuses, fn {_, s} -> s.status == :error end)
    any_skipped? = Enum.any?(statuses, fn {_, s} -> s.status == :skipped end)
    any_ok? = Enum.any?(statuses, fn {_, s} -> s.status == :ok end)

    cond do
      any_error? ->
        :unresolved

      full_closure? and any_skipped? ->
        :unresolved

      not any_ok? ->
        # Zero witnesses answered: a court that saw nothing proves nothing.
        :unresolved

      true ->
        classify(requirements, Enum.sort_by(candidates_from(statuses), & &1.capability_id))
    end
  end

  # The mechanical v1 predicate (see moduledoc). Deterministic: candidates
  # arrive sorted by capability_id and every selection step is first-max.
  defp classify([], _candidates), do: {:decided, :frontier, [], []}

  defp classify(requirements, candidates) do
    single = Enum.find(candidates, &satisfies?(&1, requirements))
    composition = if single, do: nil, else: cover(requirements, candidates)
    partial = Enum.filter(candidates, &covers_any?(&1, requirements))

    cond do
      single ->
        {:decided, :reuse, [single], nil}

      match?({:ok, _}, composition) ->
        {:decided, :compose, elem(composition, 1), nil}

      partial != [] ->
        {:decided, :extend, partial, uncovered(requirements, candidates)}

      Enum.any?(candidates, &in_family?(&1, requirements)) ->
        {:decided, :generate, [], requirements}

      true ->
        {:decided, :frontier, [], requirements}
    end
  end

  defp covers?(candidate, requirement),
    do: requirement in candidate.satisfies or candidate.capability_id == requirement

  defp satisfies?(candidate, requirements),
    do: requirements != [] and Enum.all?(requirements, &covers?(candidate, &1))

  defp covers_any?(candidate, requirements), do: Enum.any?(requirements, &covers?(candidate, &1))

  # Bounded greedy composition (the 柵 bound is explicit, never an
  # enumeration of the product): repeatedly take the candidate covering
  # the most still-uncovered requirements (ties broken by capability_id
  # order -- deterministic); stop at #{@max_composition} members or no
  # progress.
  defp cover(requirements, candidates) do
    do_cover(candidates, requirements, [])
  end

  # SUCCESS first: the terminating call arrives with an empty pool AND an
  # empty uncovered set, and the empty-pool clause below must not shadow it.
  # (Plain lists, not MapSet: `map_size/1` on a MapSet struct is the size of
  # the struct map, never 0 -- a silent-falsifier class of bug.)
  defp do_cover(_pool, [], selected), do: {:ok, Enum.reverse(selected)}

  defp do_cover([], _uncovered, _selected), do: {:error, :no_progress}

  defp do_cover(_pool, _uncovered, selected) when length(selected) >= @max_composition,
    do: {:error, :composition_bound}

  defp do_cover(pool, uncovered, selected) do
    {best, count} =
      pool
      |> Enum.map(fn candidate ->
        {candidate, Enum.count(uncovered, &covers?(candidate, &1))}
      end)
      |> Enum.max_by(fn {candidate, count} -> {count, candidate.capability_id} end)

    if count == 0 do
      {:error, :no_progress}
    else
      remaining = Enum.reject(uncovered, &covers?(best, &1))
      do_cover(List.delete(pool, best), remaining, [best | selected])
    end
  end

  defp uncovered(requirements, candidates) do
    Enum.reject(requirements, fn requirement ->
      Enum.any?(candidates, &covers?(&1, requirement))
    end)
  end

  defp in_family?(candidate, requirements) do
    family = family(candidate.capability_id)
    Enum.any?(requirements, &(family(&1) == family))
  end

  defp family(id) when is_binary(id) do
    case String.split(id, ":", parts: 2) do
      [namespace, _rest] -> namespace
      [id] -> id
    end
  end

  @doc false
  def max_composition, do: @max_composition
end
