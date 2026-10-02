defmodule Xaas.Chicago.View do
  @moduledoc """
  L6 drill-down view over the Chicago projections (resolution R4/R6).

  `drill_down/0` serves the observation surface: the exact subject, a business
  outcome (from the executive narrative when present, typed fallback otherwise)
  and exactly the 10 contract layers in contract order, each with
  `{id, label, what_happened, standing, lifecycle, evidence, receipt, absence}`.

  Standing law (R8): a layer's standing comes only from that layer's own
  machine `status` field — never from another layer, never inferred across
  surfaces. Every layer defaults to lifecycle `:candidate` and standing
  `"UNKNOWN"` until a real receipt binds observed execution (which is L5's
  runtime fold, not this projection view). `absence` is reserved for layers
  missing from the projection entirely — a present-but-unreceipted layer
  renders an interactive row, not a no-bridge row.
  """

  alias Xaas.Chicago.Layer

  @lifecycle_for_status %{
    "UNKNOWN" => :candidate,
    "PARTIAL_ALIVE" => :unknown,
    "ALIVE" => :executed,
    "BLOCKED" => :refused,
    "BUILD_BROKEN" => :refused,
    "REFUSED" => :refused
  }

  @doc "Drill-down over the default projection paths."
  @spec drill_down :: {:ok, map} | {:refused, {atom, term}}
  def drill_down, do: drill_down([])

  @doc """
  Drill-down over explicit projection paths (tests, render gate). Options:

  * `:machine_path` — machine projection path (default `Xaas.Chicago.path_for(:machine)`)
  * `:executive_path` — executive projection path (default `Xaas.Chicago.path_for(:executive)`)
  """
  @spec drill_down(keyword) :: {:ok, map} | {:refused, {atom, term}}
  def drill_down(opts) do
    machine_path = Keyword.get(opts, :machine_path, Xaas.Chicago.path_for(:machine))
    executive_path = Keyword.get(opts, :executive_path, Xaas.Chicago.path_for(:executive))

    with {:ok, machine} <- Xaas.Chicago.load_projection(:machine, machine_path) do
      executive = Xaas.Chicago.load_projection(:executive, executive_path)

      {:ok,
       %{
         subject: machine["subject"],
         business_outcome: business_outcome(executive),
         layers: Enum.map(Layer.required_ids(), &layer_view(machine, &1))
       }}
    end
  end

  # -- business outcome ------------------------------------------------------

  defp business_outcome({:ok, executive}) do
    narrative = executive["narrative"] || %{}

    %{
      headline: narrative["headline"] || fallback_headline(),
      detail:
        narrative["desiredOutcome"] || narrative["customerProblem"] ||
          fallback_detail("executive narrative incomplete"),
      standing:
        executive |> Map.get("deliveryState", %{}) |> Map.get("overallStanding") || "UNKNOWN"
    }
  end

  defp business_outcome({:refused, {_tag, reason}}) do
    %{
      headline: fallback_headline(),
      detail: fallback_detail("executive projection unavailable (#{explain(reason)})"),
      standing: "UNKNOWN"
    }
  end

  defp fallback_headline, do: "Chicago agentic payment demonstration — candidate"

  defp fallback_detail(reason),
    do:
      "Executive narrative pending a valid pack render (#{reason}). " <>
        "All layers remain candidate predictions; no outcome is pre-judged."

  defp explain({path, _reason}) when is_binary(path),
    do: "invalid projection at #{Path.basename(path)}"

  defp explain(path) when is_binary(path), do: "missing projection at #{Path.basename(path)}"
  defp explain(other), do: inspect(other)

  # -- layers ----------------------------------------------------------------

  defp layer_view(machine, id) do
    case Layer.fetch(machine, id) do
      {:ok, layer} -> layer_view_from(layer)
      {:refused, _} -> layer_view_absent(id)
    end
  end

  defp layer_view_from(layer) do
    id = String.to_existing_atom(layer["id"])
    standing = Layer.standing(layer)
    evidence = layer["evidenceRefs"] || []
    receipt = (layer["receiptRefs"] || []) |> List.first()

    %{
      id: id,
      label: layer["label"] || Layer.label(id),
      what_happened: what_happened(layer, receipt),
      standing: standing,
      lifecycle: Map.get(@lifecycle_for_status, standing, :candidate),
      evidence: evidence,
      receipt: receipt,
      absence: absence(receipt)
    }
  end

  defp what_happened(layer, receipt) when is_binary(receipt) do
    "#{layer["label"]}: observed execution receipt bound (#{receipt})."
  end

  defp what_happened(layer, nil) do
    "#{layer["label"]}: capability #{layer["capabilityId"]} declared in scope " <>
      "#{layer["repository"]}#{layer["pathScope"]}; no observed execution yet — candidate prediction only."
  end

  defp absence(receipt) when is_binary(receipt), do: nil

  # A layer present in the machine projection is bridged by construction —
  # this consumer is the xaas-side edge. Missing receipts surface as UNKNOWN
  # standing plus the panel note, not as a no-bridge absence row; `absence`
  # stays reserved for layers missing from the projection entirely.
  defp absence(nil), do: nil

  defp layer_view_absent(id) do
    %{
      id: id,
      label: Layer.label(id),
      what_happened: "#{Layer.label(id)}: not present in the machine projection.",
      standing: "UNKNOWN",
      lifecycle: :unknown,
      evidence: [],
      receipt: nil,
      absence: "no_machine_layer: contract layer missing from the rendered projection."
    }
  end
end
