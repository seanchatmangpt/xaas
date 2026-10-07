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

    gate =
      Xaas.Graphlaw.LimitGate.enforce(
        Xaas.Graphlaw.LimitGate.scope(),
        %{"max_json_depth" => Xaas.Graphlaw.LimitGate.json_depth(claim)}
      )

    case gate do
      :ok ->
        do_assess(claim, subject, opts)

      {:refused, info} ->
        {:refused, limit_refusal_envelope(subject, info)}
    end
  end

  defp do_assess(claim, subject, opts) do
    facts = purchase_facts(claim, subject)
    data = %{"text" => facts, "dialect" => "ntriples"}

    steps = [
      %{"step" => "n3", "rules" => @rules},
      %{"step" => "shacl", "shapes" => purchase_shapes(subject)}
    ]

    case gate_engine_limits(facts, data, steps) do
      :ok ->
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

      {:refused, info} ->
        {:refused, limit_refusal_envelope(subject, info)}
    end
  end

  # Lane W981k (SPEC-10 continuation): the remaining engine limits with a
  # true consumption seam at this bridge are the byte limits on the exact
  # payloads handed to the engine:
  #
  # - `max_request_bytes` (abi scope, 16 MiB) — the JSON request the bridge
  #   renders for `AshGraphLaw.law/3` (data + steps), caller-controlled via
  #   the claim;
  # - `n3_max_term_bytes` (n3 scope, 64 KiB) — the largest single N-Triples
  #   line (subject/predicate/object terms) in the rendered facts;
  # - `n3_max_total_bytes` (n3 scope, 256 MiB) — total bytes of the facts
  #   text fed to the n3 step.
  #
  # All three use the same `LimitGate.enforce/2` consumer as the depth gate;
  # a limit row that is absent or unreadable stays fail-open (the seam's
  # DB-independent court contract), and only a real recorded exceedance
  # refuses. Measured on what is actually sent — no artificial plumb-through.
  defp gate_engine_limits(facts, data, steps) do
    request_bytes =
      %{"data" => data, "steps" => steps}
      |> Jason.encode!()
      |> byte_size()

    n3_lines = String.split(facts, "\n", trim: true)
    n3_term_bytes = n3_lines |> Enum.map(&byte_size/1) |> Enum.max()
    n3_total_bytes = byte_size(facts)

    abi = Xaas.Graphlaw.LimitGate.enforce("abi", %{"max_request_bytes" => request_bytes})
    n3 = Xaas.Graphlaw.LimitGate.enforce("n3", %{"n3_max_term_bytes" => n3_term_bytes})

    n3_total =
      Xaas.Graphlaw.LimitGate.enforce("n3", %{"n3_max_total_bytes" => n3_total_bytes})

    Enum.find([abi, n3, n3_total], &match?({:refused, _}, &1)) || :ok
  end

  defp limit_refusal_envelope(subject, info) do
    envelope = Xaas.Bridges.envelope(subject, "graphlaw purchase policy", :refused)

    envelope
    |> Map.put(:code, :limit_exceeded)
    |> Map.put(:class, :refused_admission)
    |> Map.put(:broken_term, :mu_on_O)
    |> Map.put(:limit, info.limit)
    |> Map.put(:limit_value, info.limit_value)
    |> Map.put(:refusal_name, info.refusal_name)
    |> Map.put(:message, info.message)
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
