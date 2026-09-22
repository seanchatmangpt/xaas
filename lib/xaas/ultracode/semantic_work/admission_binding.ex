defmodule Xaas.Ultracode.SemanticWork.AdmissionBinding do
  @moduledoc """
  Fail-closed binding of a semantic-work descriptor's digests to the admitted
  work-order snapshot, recomputed on the XaaS side.

  The falsifier this module closes (SJ-001): *materialize accepts a WorkOrder
  whose digest was altered after admission.* An in-band digest copy alone can
  never close it (a tamperer who edits `graph_digest` edits the copy next to it
  too), so verification needs material the tamperer did not also rewrite. XaaS
  recomputes the digest itself instead of trusting a string the producer sent.

  ## Anchors (what a digest is checked against)

  In priority order, every anchor present is recomputed or read, and all must
  agree with each other:

    1. `admitted_work_order` -- the producer's admitted snapshot (the exact map
       `GgenIgniter.SemanticJira.admit_work_order/1` returned, including its
       `work_order_digest`). XaaS recomputes the digest from the snapshot's own
       content, so any edit to an admitted field after admission is refused
       (`{:admitted_snapshot_stale, recomputed}`), and the descriptor's
       `base_sha`, `repository_identity`, `work_order_iri` and bridge identity /
       repository / base_sha / definition_digest must be the snapshot's.
    2. `bridge.source_snapshot_digest` -- the graph side's per-work-order
       snapshot digest, already emitted by the real descriptor bridge.
    3. `admission_digest` -- the opt-in envelope. It is a second copy of
       `graph_digest`, so alone it is NOT an independent anchor.

  ## Binding modes

  Whether `graph_digest` itself is the snapshot digest is a property of the
  producer contract, so the trusted caller (never the descriptor) declares it:

    * `:snapshot` -- `graph_digest` MUST equal the snapshot digest and at least
      one independent anchor (1 or 2) MUST be present, else
      `:admission_anchor_missing`. A descriptor stripped of every anchor is
      refused, not waved through.
    * `:graph` -- `graph_digest` is a graph-wide digest (the ontology-graph
      digest the real `Descriptor.build/4` emits over every definition digest);
      it is not a per-work-order value and is not bound. Anchors still must
      agree with each other and the envelope, when present, must equal
      `graph_digest`.
    * `:auto` (default) -- `:snapshot` semantics when the producer carried an
      `admitted_work_order`, otherwise `:graph`.

  Refusals are typed, all wrapped as `{:refused_semantic_work, reason}`:
  `{:invalid, :admitted_work_order}`, `{:invalid, :bridge_source_snapshot_digest}`,
  `{:admitted_snapshot_stale, recomputed}`, `{:admitted_snapshot_mismatch, field}`,
  `{:admission_anchor_disagree, source_a, source_b}`,
  `{:graph_digest_unbound, anchor_source, expected}`, `:admission_anchor_missing`.

  The digest is the graph side's canonical form
  (`GgenIgniter.SemanticJira.digest/1`): digest-carrying top-level fields
  dropped, every map a key-sorted list of `[key, value]` pairs, compact JSON,
  SHA-256. XaaS already mirrors that form for receipt digests
  (`Xaas.Ultracode.SemanticReceipt.digest/1`); this module reuses it.
  """

  alias Xaas.Ultracode.SemanticReceipt

  @digest ~r/^sha256:[0-9a-f]{64}$/
  @modes [:auto, :snapshot, :graph]

  # Top-level fields the graph side never feeds into a digest
  # (GgenIgniter.SemanticJira.drop_digest_fields/1).
  @digest_fields ~w(work_order_digest transition_digest evidence_digest receipt_digest
                    experience_digest repair_digest finding_digest composition_digest)
  # Extra fields dropped for the stable definition identity
  # (GgenIgniter.SemanticJira.definition_digest/1).
  @definition_fields ~w(standing dimensions)

  @type mode :: :auto | :snapshot | :graph

  @doc "Accepted binding modes."
  @spec modes() :: [mode()]
  def modes, do: @modes

  @doc """
  The work-order snapshot digest XaaS recomputes from an admitted snapshot map.
  """
  @spec snapshot_digest(map()) :: String.t()
  def snapshot_digest(snapshot) when is_map(snapshot) do
    snapshot |> drop(@digest_fields) |> SemanticReceipt.digest()
  end

  @doc """
  The stable definition digest XaaS recomputes from an admitted snapshot map
  (the snapshot minus `standing`, `dimensions` and its digest fields).
  """
  @spec definition_digest(map()) :: String.t()
  def definition_digest(snapshot) when is_map(snapshot) do
    snapshot |> drop(@digest_fields ++ @definition_fields) |> SemanticReceipt.digest()
  end

  @doc """
  Verifies `descriptor` (an already key-normalized map, as `SemanticWork.admit/2`
  builds it) against its anchors under `mode`.
  """
  @spec verify(map(), mode()) :: :ok | {:error, {:refused_semantic_work, term()}}
  def verify(descriptor, mode) when is_map(descriptor) and mode in @modes do
    bridge = Map.get(descriptor, :bridge)

    with {:ok, snapshot} <- admitted_snapshot(descriptor),
         {:ok, bridge_digest} <- bridge_digest(bridge),
         :ok <- bind_snapshot(descriptor, snapshot, bridge),
         anchors = anchors(snapshot, bridge_digest, descriptor),
         :ok <- anchors_agree(anchors) do
      bind_graph_digest(descriptor, anchors, snapshot, mode)
    end
  end

  # -- anchors ---------------------------------------------------------------

  defp admitted_snapshot(descriptor) do
    case Map.get(descriptor, :admitted_work_order) do
      nil ->
        {:ok, nil}

      %{} = snapshot when not is_struct(snapshot) ->
        if valid_digest?(field(snapshot, :work_order_digest)),
          do: {:ok, snapshot},
          else: refuse({:invalid, :admitted_work_order})

      _ ->
        refuse({:invalid, :admitted_work_order})
    end
  end

  defp bridge_digest(%{} = bridge) when not is_struct(bridge) do
    case field(bridge, :source_snapshot_digest) do
      nil ->
        {:ok, nil}

      value ->
        if valid_digest?(value),
          do: {:ok, value},
          else: refuse({:invalid, :bridge_source_snapshot_digest})
    end
  end

  defp bridge_digest(_none), do: {:ok, nil}

  defp anchors(snapshot, bridge_digest, descriptor) do
    [
      {:admitted_work_order, snapshot && snapshot_digest(snapshot)},
      {:bridge_source_snapshot_digest, bridge_digest},
      {:admission_digest, Map.get(descriptor, :admission_digest)}
    ]
    |> Enum.reject(fn {_source, digest} -> is_nil(digest) end)
  end

  defp anchors_agree([]), do: :ok

  defp anchors_agree([{first_source, first} | rest]) do
    case Enum.find(rest, fn {_source, digest} -> digest != first end) do
      nil -> :ok
      {source, _digest} -> refuse({:admission_anchor_disagree, first_source, source})
    end
  end

  # -- the embedded snapshot's own consistency and descriptor bindings -------

  defp bind_snapshot(_descriptor, nil, _bridge), do: :ok

  defp bind_snapshot(descriptor, snapshot, bridge) do
    recomputed = snapshot_digest(snapshot)

    if recomputed != field(snapshot, :work_order_digest) do
      refuse({:admitted_snapshot_stale, recomputed})
    else
      checks =
        [
          {:base_sha, Map.get(descriptor, :base_sha) == field(snapshot, :base_sha)},
          {:repository_identity,
           Map.get(descriptor, :repository_identity) == field(snapshot, :repository)},
          {:work_order_iri, iri_names?(Map.get(descriptor, :work_order_iri), snapshot)}
        ] ++ bridge_checks(bridge, snapshot)

      case Enum.find(checks, fn {_name, ok?} -> not ok? end) do
        nil -> :ok
        {name, _} -> refuse({:admitted_snapshot_mismatch, name})
      end
    end
  end

  defp iri_names?(iri, snapshot) do
    identity = field(snapshot, :identity)
    is_binary(iri) and is_binary(identity) and String.ends_with?(iri, ":" <> identity)
  end

  # Only what the bridge actually carries is checked: an absent bridge key is
  # the producer's choice, a present-but-different one is a mismatch.
  defp bridge_checks(%{} = bridge, snapshot) when not is_struct(bridge) do
    definition = definition_digest(snapshot)

    [
      {:bridge_identity, agrees?(field(bridge, :identity), field(snapshot, :identity))},
      {:bridge_repository, agrees?(field(bridge, :repository), field(snapshot, :repository))},
      {:bridge_base_sha, agrees?(field(bridge, :base_sha), field(snapshot, :base_sha))},
      {:bridge_definition_digest, agrees?(field(bridge, :definition_digest), definition)}
    ]
  end

  defp bridge_checks(_none, _snapshot), do: []

  defp agrees?(nil, _expected), do: true
  defp agrees?(value, expected), do: value == expected

  # -- graph_digest binding --------------------------------------------------

  defp bind_graph_digest(descriptor, anchors, snapshot, mode) do
    independent = Enum.reject(anchors, fn {source, _} -> source == :admission_digest end)

    cond do
      mode == :graph ->
        :ok

      mode == :snapshot and independent == [] ->
        refuse(:admission_anchor_missing)

      mode == :snapshot or (mode == :auto and not is_nil(snapshot)) ->
        {source, expected} = hd(independent)

        if Map.get(descriptor, :graph_digest) == expected,
          do: :ok,
          else: refuse({:graph_digest_unbound, source, expected})

      true ->
        :ok
    end
  end

  # -- helpers ---------------------------------------------------------------

  defp field(map, key) when is_atom(key) do
    case Map.fetch(map, Atom.to_string(key)) do
      {:ok, value} -> value
      :error -> Map.get(map, key)
    end
  end

  defp drop(map, string_keys) do
    Map.reject(map, fn {key, _value} -> to_string(key) in string_keys end)
  end

  defp valid_digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp refuse(reason), do: {:error, {:refused_semantic_work, reason}}
end
