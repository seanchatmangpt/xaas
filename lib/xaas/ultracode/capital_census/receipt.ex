defmodule Xaas.Ultracode.CapitalCensus.Receipt do
  @moduledoc """
  The CapitalReceipt artifact of the capital census
  (`docs/sjira/v26.9.26/GC-26926-CENSUS.md`): what the fleet already knows
  how to do against one work order's observed world, so the router hands
  the executor only the irreducible residual.

  ## The law

      Gap = Required − Closure(K | O*);   Gap = ∅ ⇒ LLM reasoning = 0

  `llm_reasoning_required?/1` is that law as an executable anchor: an
  empty residual gap means every required capability is covered by
  ADMITTED capital and no LLM reasoning hop is owed. The census exists to
  make the emptiness provable rather than asserted, so the receipt carries
  the evidence distinctions it was proved with.

  ## The narrowing chain

  `found ≠ applicable ≠ admitted ≠ sufficient ≠ authorized`. Finding a
  candidate does not make it applicable; applicability does not admit it
  (admission is a court act); admission does not make it sufficient
  (closure does); sufficiency does not authorize execution (the route
  lattice + authority layer does). This module enforces the slice it owns
  as set invariants over the receipt:

    * `admitted ⊆ candidates` -- an admitted id that is not a candidate id
      is `:admitted_outside_candidates`;
    * `admitted`, `rejected`, `unknown` PARTITION `candidates`: every
      candidate is in exactly one bucket. UNKNOWN is first-class -- an
      unclassified candidate is a refusal, never a silent drop
      (`:candidates_not_partitioned`);
    * `closure` equals the union of `covers` over the admitted candidates;
      a carried closure that disagrees with the admitted set is
      `:closure_mismatch` (coverage is computed, never asserted);
    * `residual_gap` equals `required_capabilities − closure`
      (`:residual_gap_mismatch` otherwise);
    * `route` is nil or a rung of the lattice
      `Reuse ≺ Compose ≺ Rule ≺ Plan ≺ Constraint ≺ Generate ≺
      SpecializedModel ≺ LLM` (`:unknown_route` otherwise).

  Every violation is the typed refusal `{:refused, :unsupported_capability}`;
  data errors never raise. `problems/1` names the violated invariants as
  sorted atoms (`[]` exactly when `validate/1` is `:ok`).

  The receipt is a pure artifact -- a plain snake_case map, no Ecto, no
  table. Produced by the census, carried to the worker on the gall-work
  claim payload (`admitted_capital` + `residual_gap` + `falsifier`),
  consumed by the route lattice
  (`Xaas.Ultracode.CapitalCensus.Route`) and the experience ledger
  (`Xaas.Ultracode.CapitalCensus.Experience`). `new/1` accepts string- or
  atom-keyed payloads and fills the census-derived defaults; malformed
  values are carried verbatim so `validate/1` refuses them -- construction
  never raises and never silently repairs data.
  """

  @lattice ~w(reuse compose rule plan constraint generate specialized_model llm)a

  @enforced_keys ~w(observed_world required_capabilities candidates admitted rejected unknown closure residual_gap route)a

  @route_atoms Map.new(@lattice, &{Atom.to_string(&1), &1})

  @type id :: term()
  @type capability :: String.t()

  @type route ::
          :reuse
          | :compose
          | :rule
          | :plan
          | :constraint
          | :generate
          | :specialized_model
          | :llm

  @type candidate :: %{
          required(:id) => id(),
          required(:covers) => [capability()],
          optional(atom()) => term()
        }

  @type t :: %{
          required(:observed_world) => term(),
          required(:required_capabilities) => [capability()],
          required(:candidates) => [candidate()],
          required(:admitted) => [id()],
          required(:rejected) => [id()],
          required(:unknown) => [id()],
          required(:closure) => [capability()],
          required(:residual_gap) => [capability()],
          required(:route) => route() | nil
        }

  @doc """
  The route lattice, ascending capability:
  `Reuse ≺ Compose ≺ Rule ≺ Plan ≺ Constraint ≺ Generate ≺
  SpecializedModel ≺ LLM`.
  """
  @spec lattice() :: [route(), ...]
  def lattice, do: @lattice

  @doc """
  Builds the receipt with census defaults: missing buckets default to
  `[]`, `closure` defaults to the computed coverage of the admitted
  candidates, `residual_gap` defaults to `required_capabilities −
  closure`, `route` defaults to nil (the route is the router's decision,
  not the census's). String-keyed payloads (JSON claim blocks) and string
  rungs (`"plan"`) are normalized; malformed values are carried verbatim
  so `validate/1` refuses them.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    required = present(attrs, :required_capabilities, [])
    candidates = present(attrs, :candidates, [])
    admitted = present(attrs, :admitted, [])
    rejected = present(attrs, :rejected, [])
    unknown = present(attrs, :unknown, [])

    closure =
      case list_only(present(attrs, :closure, nil)) do
        nil -> covered(admitted, candidates)
        carried -> carried
      end

    residual_gap =
      case list_only(present(attrs, :residual_gap, nil)) do
        nil -> required_minus(required, closure)
        gap -> gap
      end

    %{
      observed_world: present(attrs, :observed_world, nil),
      required_capabilities: required,
      candidates: candidates,
      admitted: admitted,
      rejected: rejected,
      unknown: unknown,
      closure: closure,
      residual_gap: residual_gap,
      route: normalize_route(present(attrs, :route, nil))
    }
  end

  @doc """
  `:ok` when the receipt is a well-formed census artifact whose invariant
  chain holds (`admitted ⊆ candidates`, the admitted/rejected/unknown
  partition, carried closure == computed coverage, carried residual_gap ==
  required − closure, route on the lattice); the typed refusal
  `{:refused, :unsupported_capability}` otherwise. Never raises.
  """
  @spec validate(term()) :: :ok | {:refused, :unsupported_capability}
  def validate(receipt) do
    case problems(receipt) do
      [] -> :ok
      _problems -> {:refused, :unsupported_capability}
    end
  end

  @doc """
  The violated invariants as sorted atoms -- `[]` exactly when `validate/1`
  is `:ok`. `[:invalid_schema]` for any non-map receipt, a missing key, a
  malformed capability/bucket list, or a duplicate candidate id.
  """
  @spec problems(term()) :: [atom()]
  def problems(receipt) when is_map(receipt) do
    if schema_problem?(receipt) do
      [:invalid_schema]
    else
      invariant_problems(receipt)
    end
  end

  def problems(_), do: [:invalid_schema]

  @doc """
  Closure(K | O*) for the receipt: the sorted union of `covers` over the
  ADMITTED candidates. Found or rejected capital contributes nothing --
  only admission closes capability. Defensive on malformed input.
  """
  @spec closure(term()) :: [capability()]
  def closure(receipt) when is_map(receipt) do
    covered(Map.get(receipt, :admitted, []), Map.get(receipt, :candidates, []))
  end

  def closure(_), do: []

  @doc """
  The live computation of `required_capabilities − closure/1` (the carried
  `residual_gap` must equal it -- `validate/1` refuses the disagreement).
  Defensive on malformed input: `[]` for a non-map receipt.
  """
  @spec residual_gap(term()) :: [capability()]
  def residual_gap(receipt) when is_map(receipt) do
    required_minus(Map.get(receipt, :required_capabilities), closure(receipt))
  end

  def residual_gap(_), do: []

  @doc """
  The census law as a predicate: `Gap = ∅ ⇒ LLM reasoning = 0`. True
  exactly when the live residual gap is non-empty, i.e. the executor owes
  at least one reasoning hop the admitted capital cannot cover.
  """
  @spec llm_reasoning_required?(term()) :: boolean()
  def llm_reasoning_required?(receipt), do: residual_gap(receipt) != []

  # ------------------------------------------------------------------
  # Construction
  # ------------------------------------------------------------------

  defp present(attrs, key, default) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key), default)
    end
  end

  defp list_only(value) when is_list(value), do: value
  defp list_only(_), do: nil

  defp normalize_route(route) when is_binary(route), do: Map.get(@route_atoms, route, route)
  defp normalize_route(route), do: route

  defp required_minus(required, closure) when is_list(required) and is_list(closure) do
    required |> Enum.uniq() |> Enum.reject(&(&1 in closure))
  end

  defp required_minus(_, _), do: []

  # Total on purpose: new/1 must carry malformed bucket values verbatim for
  # validate/1 to refuse (:invalid_schema), never crash on them (found via
  # the anti-vacuity mutation test).
  defp covered(admitted, candidates) when is_list(admitted) and is_list(candidates) do
    covers =
      candidates
      |> Map.new(fn candidate -> {cand_id(candidate), covers_of(candidate)} end)

    admitted
    |> Enum.flat_map(&Map.get(covers, &1, []))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp covered(_, _), do: []

  # ------------------------------------------------------------------
  # Invariants
  # ------------------------------------------------------------------

  defp schema_problem?(receipt) do
    Enum.any?(@enforced_keys, &(not Map.has_key?(receipt, &1))) or
      not cap_list?(Map.get(receipt, :required_capabilities)) or
      not list?(Map.get(receipt, :admitted)) or
      not list?(Map.get(receipt, :rejected)) or
      not list?(Map.get(receipt, :unknown)) or
      not cap_list?(Map.get(receipt, :closure)) or
      not cap_list?(Map.get(receipt, :residual_gap)) or
      not candidates_ok?(Map.get(receipt, :candidates))
  end

  defp invariant_problems(receipt) do
    candidate_ids = MapSet.new(Enum.map(receipt.candidates, &cand_id/1))
    bucket_ids = receipt.admitted ++ receipt.rejected ++ receipt.unknown
    admitted_set = MapSet.new(receipt.admitted)

    problems = []

    problems =
      if MapSet.size(MapSet.difference(admitted_set, candidate_ids)) > 0 do
        [:admitted_outside_candidates | problems]
      else
        problems
      end

    problems =
      if bucket_ids == Enum.uniq(bucket_ids) and
           MapSet.equal?(MapSet.new(bucket_ids), candidate_ids) do
        problems
      else
        [:candidates_not_partitioned | problems]
      end

    problems =
      if MapSet.equal?(MapSet.new(receipt.closure), MapSet.new(closure(receipt))) do
        problems
      else
        [:closure_mismatch | problems]
      end

    problems =
      if MapSet.equal?(MapSet.new(receipt.residual_gap), MapSet.new(residual_gap(receipt))) do
        problems
      else
        [:residual_gap_mismatch | problems]
      end

    problems = if valid_route?(receipt.route), do: problems, else: [:unknown_route | problems]

    Enum.sort(problems)
  end

  defp valid_route?(nil), do: true
  defp valid_route?(route) when is_atom(route), do: route in @lattice
  defp valid_route?(_), do: false

  defp list?(value) when is_list(value), do: true
  defp list?(_), do: false

  defp cap_list?(value) when is_list(value), do: Enum.all?(value, &is_binary/1)
  defp cap_list?(_), do: false

  defp candidates_ok?(candidates) when is_list(candidates) do
    ids = Enum.map(candidates, &cand_id/1)

    ids == Enum.uniq(ids) and
      Enum.all?(candidates, fn candidate ->
        is_map(candidate) and id?(candidate) and cap_list?(covers_strict(candidate))
      end)
  end

  defp candidates_ok?(_), do: false

  defp id?(%{id: id}) when not is_nil(id), do: true
  defp id?(%{"id" => id}), do: not is_nil(id)
  defp id?(_), do: false

  defp cand_id(%{id: id}), do: id
  defp cand_id(%{"id" => id}), do: id
  defp cand_id(_), do: nil

  # Strict read for SCHEMA admission: a candidate without a covers list is
  # refused, not defaulted.
  defp covers_strict(%{covers: covers}), do: covers
  defp covers_strict(%{"covers" => covers}), do: covers
  defp covers_strict(_), do: :covers_missing

  # Lenient read for COMPUTATION: only well-typed covers contribute.
  defp covers_of(candidate) do
    case covers_strict(candidate) do
      covers when is_list(covers) -> covers
      _ -> []
    end
  end
end
