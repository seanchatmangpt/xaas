defmodule Xaas.Ultracode.SemanticReceipt do
  @moduledoc """
  Exports the sealed receipt of a semantic-work Epoch in the contract the
  canonical work graph's reconciler consumes
  (`GgenIgniter.SemanticJira.Descriptor.receipt_from_xaas/2`):

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
  without that key. "Canonical" is the graph side's
  `GgenIgniter.SemanticJira.digest_exact/1`: every map becomes a list of
  `[key, value]` pairs sorted by key, atoms become strings, and the result is
  encoded as compact JSON.

  Court-specific observations come from an adapter keyed by the Run's
  verifier suite name (`Xaas.Ultracode.SemanticReceipt.ApsDod`). A suite
  without an adapter whose sealed court receipt was PRODUCED by the fabric
  (`Xaas.Ultracode.CourtReceipt.produce/6` -- it always carries a
  `"binding"`) passes its IRI-keyed `acceptance_results` /
  `falsifier_results` / `court_results` and the `binding` through verbatim:
  those verdicts are already in the consumer's vocabulary. Any other suite
  exports only step statuses.
  """

  alias Xaas.Ultracode.{Epoch, Receipt, Run}
  alias Xaas.Ultracode.SemanticReceipt.ApsDod

  @adapters %{"aps-dod" => ApsDod}

  @spec export(String.t()) :: {:ok, map()} | {:error, term()}
  def export(epoch_id) when is_binary(epoch_id) do
    with {:ok, export, _sealed_verifier} <- sealed(epoch_id), do: {:ok, export}
  end

  @doc """
  Re-reads what the fabric sealed for `epoch_id`: `{:ok, export, verifier}`
  where `export` is exactly `export/1`'s map and `verifier` is the closing
  receipt's raw `"fabric_verifier"` evidence (every step with its observed
  `"exit"`), or `nil` when the close ran no verifier. A caller holding an
  export can compare its `receipt_digest` with this re-export to prove the
  fabric sealed it: the digest itself is unkeyed, so it proves integrity,
  never provenance.
  """
  @spec sealed(String.t()) :: {:ok, map(), map() | nil} | {:error, term()}
  def sealed(epoch_id) when is_binary(epoch_id) do
    with {:ok, epoch} <- fetch(Epoch, epoch_id, :epoch_not_found),
         {:ok, run} <- fetch(Run, epoch.run_id, :run_not_found),
         {:ok, bridge} <- bridge(run),
         :ok <- completed(epoch),
         {:ok, closing} <- closing_receipt(epoch) do
      {:ok, build(epoch, run, closing, bridge), closing.evidence["fabric_verifier"]}
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
      "fabric_verifier" => fabric_verifier(verifier, run.verifier_suite, bridge),
      "bridge" => bridge
    }

    normalized = json_normalize(export)
    Map.put(normalized, "receipt_digest", receipt_digest(normalized))
  end

  defp fabric_verifier(%{} = verifier, suite, bridge) do
    steps =
      Enum.map(verifier["steps"] || [], fn step ->
        %{"id" => step["id"], "status" => step["status"]}
      end)

    courts = get_in(bridge, ["requires", "courts"]) || []
    aliases = court_steps(suite, steps, courts)
    base = %{"status" => verifier["status"], "steps" => steps ++ aliases}

    case observed(suite, verifier["court_receipt"], bridge) do
      nil -> base
      court -> Map.put(base, "court_receipt", court)
    end
  end

  defp fabric_verifier(_none, _suite, _bridge), do: %{"status" => "none", "steps" => []}

  defp court_steps(suite, steps, courts) do
    case Map.get(@adapters, suite) do
      nil -> []
      adapter -> adapter.court_steps(steps, courts)
    end
  end

  @passthrough_keys ~w(acceptance_results falsifier_results court_results binding)

  defp observed(suite, court_receipt, bridge) do
    case {Map.get(@adapters, suite), court_receipt} do
      {nil, %{"binding" => %{}} = produced} ->
        Map.take(produced, @passthrough_keys)

      {adapter, %{} = court} when not is_nil(adapter) ->
        adapter.observe(court, get_in(bridge, ["requires"]) || %{})

      _ ->
        nil
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
