defmodule Xaas.Ultracode.CapitalCensus.SelfDigest.Law do
  @moduledoc """
  The digest law over generated FACTS and generated Ash resources
  (GC-26927-SELFDIGEST, Ash-spine correction).

  This module is the ledgered handwritten residue: Ash's generators
  manufacture the state shapes (resources, enums, domain registration) and
  the facts (`Xaas.Ultracode.CapitalCensus.Facts`, an ontology projection),
  but no generator in the fleet manufactures arbitrary pure predicates — see
  HANDWRITTEN.md. Everything this module CONSUMES is manufactured; nothing
  here hardcodes a classification value, a threshold, or a G-table row.

  Laws:
    - `R_t = frontier / total`, drive dR/dt < 0 (`frontier_ratio/2`, `improving?/2`)
    - equiv(e_i, e_j) = same required_closure ∧ same residual_shape ∧ same context
      (`topology_key/1`, `cluster/2`)
    - classification is a HYPOTHESIS from the ontology's classified shapes;
      unknown never guesses (`classify/1`)
    - provenance is admission: no falsifier, no receipt, no work order
      (`self_work_order/1`)
  """

  alias Xaas.Ultracode.CapitalCensus.Facts

  @typedoc "equiv over the semantic topology triple"
  @type topology :: {String.t(), String.t(), String.t()}

  @spec frontier_ratio(non_neg_integer(), non_neg_integer()) :: float()
  def frontier_ratio(frontier, total) when total > 0 and frontier >= 0, do: frontier / total
  def frontier_ratio(_frontier, 0), do: 0.0

  @spec improving?(number() | :undefined | nil, number() | :undefined | nil) :: boolean()
  def improving?(prev, cur) when is_number(prev) and is_number(cur), do: prev > cur
  def improving?(_, _), do: false

  @spec topology_key(map()) :: topology()
  def topology_key(%{required_closure: closure, residual_shape: shape, context: context}),
    do: {closure, shape, context}

  @doc "Cluster experiences by topology triple; `recurring?` at the ontology threshold."
  @spec cluster([map()], pos_integer() | nil) :: [
          %{
            topology: topology(),
            episodes: [map()],
            count: non_neg_integer(),
            recurring?: boolean()
          }
        ]
  def cluster(experiences, threshold \\ nil) do
    threshold = threshold || Facts.recurrence_threshold()

    experiences
    |> Enum.group_by(&topology_key/1)
    |> Enum.map(fn {topology, episodes} ->
      count = length(episodes)
      %{topology: topology, episodes: episodes, count: count, recurring?: count >= threshold}
    end)
  end

  @doc """
  Classification hypothesis: `{:hypothesis, class, primitive}` when the
  ontology classifies the shape, `{:unknown, nil, nil}` when it does not.
  The unknown arm is the guard that keeps recurrences from becoming guesses.
  """
  @spec classify(%{residual_shape: String.t()}) ::
          {:hypothesis, atom(), atom()} | {:unknown, nil, nil}
  def classify(%{residual_shape: shape}) do
    case Enum.find(Facts.shape_classes(), &(&1.shape == shape)) do
      nil -> {:unknown, nil, nil}
      %{class: class, primitive: primitive} -> {:hypothesis, class, primitive}
    end
  end

  @doc """
  Build WorkOrder create-attrs from a recurring cluster.

    * `{:refused, :below_threshold}` — noise, not recurrence
    * `{:refused, :unknown_class}` — the ontology does not classify the shape
    * `{:refused, :missing_provenance}` — no falsifier or no receipt
    * `{:ok, attrs}` — admitted to `CapitalCensus.WorkOrder` create
  """
  @spec self_work_order(%{
          required(:count) => non_neg_integer(),
          required(:topology) => topology(),
          optional(atom()) => term()
        }) :: {:ok, map()} | {:refused, :below_threshold | :unknown_class | :missing_provenance}
  def self_work_order(%{count: count, topology: {closure, shape, context}} = gap)
      when is_integer(count) and count > 0 do
    cond do
      count < Facts.recurrence_threshold() ->
        {:refused, :below_threshold}

      true ->
        build_order(gap, closure, shape, context)
    end
  end

  def self_work_order(_), do: {:refused, :unknown_class}

  defp build_order(gap, closure, shape, context) do
    with {:ok, class, primitive} <- classified(shape),
         falsifier when is_binary(falsifier) and falsifier != "" <- Map.get(gap, :falsifier),
         receipt when is_binary(receipt) and receipt != "" <- Map.get(gap, :derived_from_receipt) do
      {:ok,
       %{
         ticket_id: ticket_id(shape, context),
         subject: Map.get(gap, :subject, "ultracode-self-digest"),
         observed:
           "#{gap.count} episodes required equivalent repair of topology " <>
             "#{inspect({closure, shape, context})}",
         expected: "admitted capabilities should compose without frontier coding",
         residual: "recurring residual shape `#{shape}`",
         classification: class,
         candidate_repair: "manufacture primitive `#{primitive}` for shape `#{shape}`",
         falsifier: falsifier,
         success_criteria: "replayed episodes resolve without frontier coding",
         derived_from_receipt: receipt,
         status: :open
       }}
    else
      :error -> {:refused, :unknown_class}
      _ -> {:refused, :missing_provenance}
    end
  end

  defp classified(shape) do
    case classify(%{residual_shape: shape}) do
      {:hypothesis, class, primitive} -> {:ok, class, primitive}
      {:unknown, nil, nil} -> :error
    end
  end

  defp ticket_id(shape, context) do
    hash = :erlang.phash2({shape, context}) |> Integer.to_string(36)
    "GC-#{Calendar.strftime(DateTime.utc_now(), "%y%m%d")}-SELF-#{hash}"
  end

  @doc """
  Render self-tickets as sJira markdown (the RENDER boundary — prose lives
  only here, never in state). One block per work order.
  """
  @spec render_tickets([map()]) :: String.t()
  def render_tickets(orders) do
    Enum.map_join(orders, "\n\n", fn o ->
      """
      ## #{o.ticket_id}

      ```text
      Observed:       #{o.observed}
      Expected:       #{o.expected}
      Residual:       #{o.residual}
      Classification: #{o.classification}
      Candidate repair: #{o.candidate_repair}
      Falsifier:      #{o.falsifier}
      Success:        #{o.success_criteria}
      Provenance:     #{o.derived_from_receipt}
      ```
      """
    end)
  end
end
