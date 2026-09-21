defmodule Xaas.Ultracode.SemanticReceipt do
  @moduledoc """
  Exports the sealed receipt of a semantic-work Epoch in the wire contract
  `Xaas.Ultracode.SemanticJiraBridge.reconciler_receipt/2` maps onto the
  canonical work graph's reconciler (`GgenIgniter.SemanticJira.Reconciler`):

      %{"epoch_id", "run_id", "receipt_id", "receipt_digest", "outcome",
        "final_head", "head_verified",
        "fabric_verifier" => %{"status", "steps" => [%{"id", "status"}],
                               "court_receipt" => %{...observations...}},
        "bridge" => <the descriptor bridge, verbatim>}

  Everything here is read back from what the fabric sealed: the closing
  Receipt, its `head_verified` flag and the verifier verdict recorded by
  `Lease.close/4`. Nothing is promoted or inferred: a field the fabric did not
  observe is absent, and the graph side treats absent as unobserved. The
  `bridge` stored on the Run is opaque and echoed byte-for-byte as JSON.

  `receipt_digest` is `sha256:` + hex of the canonical JSON of the export
  without that key: every map becomes a list of `[key, value]` pairs sorted by
  key, atoms become strings, and the result is encoded as compact JSON. On an
  export this is the graph side's `GgenIgniter.SemanticJira.digest/1`
  byte-for-byte (proved by `SemanticJiraBridgeTest`), EXCEPT that the kernel
  digest silently drops seven reserved top-level keys (`work_order_digest`,
  `transition_digest`, `evidence_digest`, `receipt_digest`, ...), so a foreign
  export carrying one of them would verify under the kernel digest but not
  here. That divergence is why this module keeps its own digest instead of
  delegating (see the same test's falsifier).

  Court-specific observations come from an adapter keyed by the Run's
  verifier suite name (`Xaas.Ultracode.SemanticReceipt.ApsDod`), except that a
  court receipt PRODUCED by the fabric (`Xaas.Ultracode.CourtReceipt`) is
  exported verbatim for any suite. Suites with neither export only step
  statuses.

  "Produced by the fabric" is checked here, not read off the receipt: the Run
  must carry a court map (only `CourtReceipt.produce/6` runs, and only for a Run
  that has one), and the receipt's `"binding"` must name this Run's suite, this
  epoch's sealed head and a step the verifier really ran. A `"binding"` alone is
  not a trust marker (the suite step's printed output is worker-reachable, and
  `Verifier` also refuses to record a legacy script line that carries one).
  """

  alias Xaas.Ultracode.{Epoch, Receipt, Run}
  alias Xaas.Ultracode.SemanticReceipt.ApsDod

  @adapters %{"aps-dod" => ApsDod}

  @spec export(String.t()) :: {:ok, map()} | {:error, term()}
  def export(epoch_id) when is_binary(epoch_id) do
    with {:ok, epoch} <- fetch(Epoch, epoch_id, :epoch_not_found),
         {:ok, run} <- fetch(Run, epoch.run_id, :run_not_found),
         {:ok, bridge} <- bridge(run),
         :ok <- completed(epoch),
         {:ok, closing} <- closing_receipt(epoch) do
      {:ok, build(epoch, run, closing, bridge)}
    end
  end

  @doc "Digest a receipt export must carry in `\"receipt_digest\"`."
  @spec receipt_digest(map()) :: String.t()
  def receipt_digest(export) do
    export
    |> json_normalize()
    |> Map.delete("receipt_digest")
    |> digest()
  end

  @doc false
  @spec digest(term()) :: String.t()
  def digest(value) do
    encoded = value |> canonical() |> Jason.encode!()
    "sha256:" <> (:crypto.hash(:sha256, encoded) |> Base.encode16(case: :lower))
  end

  @doc false
  def canonical(%{} = map) when not is_struct(map) do
    map
    |> Enum.map(fn {key, value} -> [to_string(key), canonical(value)] end)
    |> Enum.sort_by(&hd/1)
  end

  def canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  def canonical(value) when is_boolean(value) or is_nil(value), do: value
  def canonical(value) when is_atom(value), do: Atom.to_string(value)
  def canonical(value), do: value

  defp build(epoch, run, closing, bridge) do
    evidence = closing.evidence
    verifier = evidence["fabric_verifier"]

    export = %{
      "epoch_id" => epoch.id,
      "run_id" => run.id,
      "receipt_id" => closing.id,
      "outcome" => to_string(closing.outcome),
      "final_head" => epoch.final_head,
      "head_verified" => evidence["head_verified"] == true,
      "fabric_verifier" => fabric_verifier(verifier, run, epoch, bridge),
      "bridge" => bridge
    }

    normalized = json_normalize(export)
    Map.put(normalized, "receipt_digest", receipt_digest(normalized))
  end

  defp fabric_verifier(%{} = verifier, %Run{verifier_suite: suite} = run, epoch, bridge) do
    steps =
      Enum.map(verifier["steps"] || [], fn step ->
        %{"id" => step["id"], "status" => step["status"]}
      end)

    courts = get_in(bridge, ["requires", "courts"]) || []
    aliases = court_steps(suite, steps, courts)
    base = %{"status" => verifier["status"], "steps" => steps ++ aliases}

    case observed(run, epoch, steps, verifier["court_receipt"], bridge) do
      nil -> base
      court -> Map.put(base, "court_receipt", court)
    end
  end

  defp fabric_verifier(_none, _run, _epoch, _bridge), do: %{"status" => "none", "steps" => []}

  defp court_steps(suite, steps, courts) do
    case Map.get(@adapters, suite) do
      nil -> []
      adapter -> adapter.court_steps(steps, courts)
    end
  end

  # A court receipt PRODUCED by the fabric is fabric-owned evidence: exported
  # verbatim so the receipt digest binds the IRI-keyed verdicts the graph side
  # promotes on. A legacy suite-script court receipt still needs its adapter.
  defp observed(run, epoch, steps, court_receipt, bridge) do
    if fabric_produced?(court_receipt, run, epoch, steps) do
      court_receipt
    else
      adapted(run.verifier_suite, court_receipt, bridge)
    end
  end

  # Only a Run with a court map has a fabric court, and the receipt must be bound
  # to THIS run's suite, THIS epoch's sealed head and a step the verifier ran.
  defp fabric_produced?(
         %{"binding" => %{} = binding},
         %Run{court_map: %{} = court_map} = run,
         epoch,
         steps
       )
       when map_size(court_map) > 0 do
    binding["suite"] == run.verifier_suite and binding["head"] == epoch.final_head and
      is_binary(binding["step_id"]) and Enum.any?(steps, &(&1["id"] == binding["step_id"]))
  end

  defp fabric_produced?(_court_receipt, _run, _epoch, _steps), do: false

  defp adapted(suite, court_receipt, bridge) do
    with adapter when not is_nil(adapter) <- Map.get(@adapters, suite),
         %{} = court <- court_receipt do
      adapter.observe(court, get_in(bridge, ["requires"]) || %{})
    else
      _ -> nil
    end
  end

  defp bridge(%Run{semantic_bridge: %{} = bridge}), do: {:ok, bridge}
  defp bridge(%Run{}), do: {:error, :no_semantic_bridge}

  defp completed(%Epoch{state: :completed}), do: :ok
  defp completed(%Epoch{state: state}), do: {:error, {:epoch_not_completed, state}}

  defp closing_receipt(%Epoch{id: id}) do
    receipts =
      Receipt
      |> Ash.Query.for_read(:for_epoch, %{epoch_id: id})
      |> Ash.read!(authorize?: false)

    case Enum.find(receipts, &Map.has_key?(&1.evidence, "head_verified")) do
      nil -> {:error, :no_closing_receipt}
      receipt -> {:ok, receipt}
    end
  end

  defp fetch(resource, id, missing) do
    case Ash.get(resource, id, action: :read_unscoped, authorize?: false) do
      {:ok, %{} = record} -> {:ok, record}
      _ -> {:error, missing}
    end
  end

  defp json_normalize(value), do: value |> Jason.encode!() |> Jason.decode!()
end
