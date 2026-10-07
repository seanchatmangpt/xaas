defmodule Xaas.Bridges.Graphlaw do
  @moduledoc """
  GraphLaw bridge: purchase-policy assessment through the pinned WASM engine.

  The bridge renders the purchase claim into N-Triples facts on the exact
  subject URN (the SHACL focus node), and the ENGINE owns the law:

    1. an N3 step derives `chi:clearance` for purchases that are within limit
       or that carry a granted approval;
    2. a SHACL step requires every purchase focused on the subject to carry a
       clearance — an over-limit purchase without approval derives none and the
       engine refuses the admission (`:not_admitted`).

  The comparison logic lives in the engine's derivation, not here. A dead host
  surfaces as the host's own typed refusal (`:host_not_started`); it is never
  papered over into a green result. GraphLaw derives and validates; it never
  authorizes.
  """

  @chi "https://w3id.org/chicago#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  @rules """
  @prefix chi: <#{@chi}> .
  { ?p chi:overLimit "false" } => { ?p chi:clearance "auto-ok" } .
  { ?p chi:overLimit "true" . ?p chi:approval "granted" } => { ?p chi:clearance "human-approved" } .
  """

  @doc "The N3 derivation rules sent to the engine."
  def rules, do: @rules

  @doc """
  Renders the purchase claim into N-Triples facts on `subject`.

  The subject URN appears byte-for-byte in the data; mutating one character of
  the subject produces different facts (no fuzzy matching anywhere).
  """
  @spec purchase_facts(map(), String.t()) :: String.t()
  def purchase_facts(claim, subject \\ Xaas.Bridges.subject()) when is_map(claim) do
    amount_n = Xaas.Bridges.PPlan.number(claim["amount"])
    limit_n = Xaas.Bridges.PPlan.number(claim["limit"])

    over_limit =
      not is_nil(amount_n) and not is_nil(limit_n) and amount_n > limit_n

    approval = if claim["approved"], do: "granted", else: "pending"

    [
      ~s(<#{subject}> <#{@rdf_type}> <#{@chi}Purchase> .\n),
      ~s(<#{subject}> <#{@chi}amount> "#{claim["amount"]}" .\n),
      ~s(<#{subject}> <#{@chi}limit> "#{claim["limit"]}" .\n),
      ~s(<#{subject}> <#{@chi}overLimit> "#{over_limit}" .\n),
      ~s(<#{subject}> <#{@chi}approval> "#{approval}" .\n)
    ]
    |> Enum.join()
  end

  @doc "The SHACL shapes gating the purchase, with the subject as focus node."
  @spec purchase_shapes(String.t()) :: String.t()
  def purchase_shapes(subject \\ Xaas.Bridges.subject()) do
    """
    @prefix sh: <http://www.w3.org/ns/shacl#> .
    @prefix chi: <#{@chi}> .
    <#{subject}-clearance-shape> a sh:NodeShape ;
      sh:targetClass chi:Purchase ;
      sh:targetNode <#{subject}> ;
      sh:property [ sh:path chi:clearance ; sh:minCount 1 ] .
    """
  end

  @doc """
  Assesses the purchase claim under the engine's law.

  `opts` pass through to `AshGraphLaw.law/3` (`:server`, `:timeout`, ...). The
  default server is the configured pool; a pool with no live host returns the
  host layer's own `:host_not_started` refusal.
  """
  @spec assess(map(), keyword()) :: {:ok, map()} | {:refused, map()}
  def assess(claim, opts \\ []) when is_map(claim) and is_list(opts) do
    subject = Keyword.get(opts, :subject) || Xaas.Bridges.subject()

    data = %{"text" => purchase_facts(claim, subject), "dialect" => "ntriples"}

    steps = [
      %{"step" => "n3", "rules" => @rules},
      %{"step" => "shacl", "shapes" => purchase_shapes(subject)}
    ]

    law_opts = Keyword.delete(opts, :subject)

    case AshGraphLaw.law(data, steps, law_opts) do
      {:ok, %AshGraphLaw.Admitted{} = admitted} ->
        {:ok, admitted_envelope(subject, admitted)}

      {:error, %AshGraphLaw.Refusal{code: code} = refusal} ->
        envelope = Xaas.Bridges.envelope(subject, "graphlaw purchase policy", :refused)

        {:refused,
         envelope
         |> Map.put(:code, code)
         |> Map.put(:class, refusal.class)
         |> Map.put(:broken_term, Map.get(refusal, :broken_term))
         |> Map.put(:message, AshGraphLaw.Refusal.message(refusal))}
    end
  end

  defp admitted_envelope(subject, %AshGraphLaw.Admitted{} = admitted) do
    receipts = admitted.receipts || []
    first = List.first(receipts)

    envelope =
      Xaas.Bridges.envelope(subject, "graphlaw purchase policy", :admitted, "PARTIAL_ALIVE")

    envelope
    |> Map.put(:receipt_ref, receipt_ref(first))
    |> Map.put(:evidence_ref, evidence_ref(first))
    |> Map.put(:provenance, %{
      receipts: length(receipts),
      authorities: Enum.map(receipts, & &1.authority),
      engine_sha256: AshGraphLaw.engine_sha256(),
      steps: Enum.map(receipts, & &1.step)
    })
  end

  defp receipt_ref(nil), do: nil

  defp receipt_ref(receipt),
    do: "graphlaw.receipt:" <> to_string(receipt.plan_sha256 || receipt.index)

  defp evidence_ref(nil), do: nil
  defp evidence_ref(receipt), do: "graphlaw.step:" <> to_string(receipt.step)
end
