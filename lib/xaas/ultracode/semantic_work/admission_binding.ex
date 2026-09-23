defmodule Xaas.Ultracode.SemanticWork.AdmissionBinding do
  @moduledoc """
  Fail-closed binding of a semantic-work descriptor to the admitted work-order
  snapshot, recomputed on the XaaS side.

  The falsifier this module closes (SJ-001): *materialize accepts a WorkOrder
  whose digest was altered after admission.* An in-band digest copy alone can
  never close it (a tamperer who edits `graph_digest` edits the copy next to it
  too), so verification needs material the tamperer did not also rewrite. XaaS
  recomputes the digest itself instead of trusting a string the producer sent,
  and it never lets the descriptor decide whether it is checked.

  ## Anchors (what a digest is checked against)

    1. `expected_snapshot_digest` / `expected_graph_digest` -- OUT-OF-BAND
       trust roots the trusted caller supplies (an operator's admission record,
       a pin captured before the descriptor touched disk). They are the only
       anchors a tamperer cannot rewrite together with the descriptor.
    2. `admitted_work_order` -- the producer's admitted snapshot (the exact map
       `GgenIgniter.SemanticJira.admit_work_order/1` returned, including its
       `work_order_digest`). XaaS recomputes the digest from the snapshot's own
       content, so any edit to an admitted field after admission is refused
       (`{:admitted_snapshot_stale, recomputed}`). In-band.
    3. `bridge.source_snapshot_digest` -- the graph side's per-work-order
       snapshot digest, already emitted by the real descriptor bridge. In-band.
    4. `admission_digest` -- the opt-in envelope. It is a second copy of
       `graph_digest`, so alone it is NOT an independent anchor.

  Every anchor present must agree with every other.

  ## What a carried snapshot binds

  When the descriptor carries `admitted_work_order`, every descriptor field the
  emitter derives deterministically from that snapshot must be exactly the
  snapshot's projection, else `{:admitted_snapshot_mismatch, field}`:

    * `base_sha`, `repository_identity`, `work_order_iri`;
    * `goal` -- one of the two emitter projections of the snapshot (the
      `"<title>: <description>"` form of the XaaS-side driver, or the
      multi-line form `GgenIgniter.SemanticJira.Descriptor` builds);
    * `checkpoint_iri` -- `urn:semantic-jira:checkpoint:<identity>@<digest>` or,
      when the bridge carries a `ledger_tail`, `...:checkpoint:<ledger_tail>`,
      each optionally followed by a `:suffix`;
    * `dependencies` -- exactly the upstream work orders the snapshot names (no
      injected or dropped edge; the receipt digests of those edges come from
      the producer's ledger and are not recomputable here);
    * when a bridge is present: `identity`, `repository`, `base_sha`,
      `definition_digest`, `subject`, and `requires` (exactly `courts`,
      `acceptance`, `falsifiers`, equal to the snapshot's `required_courts`,
      `acceptance`, `falsifiers`); `evidence_ceiling` and `replay_identity`
      must match when present. A missing key is a mismatch, not a pass.

  NOT bound (operator/registry parameters, not functions of the snapshot):
  `provider`, `verifier_suite`, `execution_policy`, `execution_repo_alias`,
  `court_map`, and the receipt digests inside `dependencies`.

  ## Binding modes

  The trusted caller -- never the descriptor -- declares how `graph_digest`
  relates to the snapshot. There is deliberately NO content-selected mode: a
  mode that turns the guard on only when the descriptor carries a snapshot lets
  the tamperer turn it off by deleting the snapshot (this was `:auto`; it is
  refused as `{:invalid_binding_option, :auto}`).

    * `:snapshot` (the default, fail-closed) -- `graph_digest` MUST equal the
      snapshot digest and at least one in-band anchor (2 or 3) MUST be present,
      else `:admission_anchor_missing`. A descriptor stripped of every anchor
      is refused, not waved through.
    * `:graph` -- explicit opt-out for a producer whose `graph_digest` is a
      graph-wide digest (the shape the real `Descriptor.build/4` emits over
      every definition digest). `graph_digest` is bound only by
      `expected_graph_digest` when the caller supplies one. Anchors present
      must still agree with each other. Without a pin, an in-band tamper of a
      graph-wide descriptor is NOT detectable: no in-band rule can tell it from
      an untampered one.

  ## Pins

    * `expected_graph_digest` -- `graph_digest` MUST equal it, in either mode.
    * `expected_snapshot_digest` -- every in-band anchor MUST equal it, and at
      least one MUST be present (a pin that has nothing to compare against
      refuses with `:admission_anchor_missing`, it does not pass vacuously).

  Refusals are typed, all wrapped as `{:refused_semantic_work, reason}`:
  `{:invalid, :admitted_work_order}`, `{:invalid, :bridge_source_snapshot_digest}`,
  `{:invalid_binding_option, value}`, `{:invalid_expected_digest, key}`,
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
  @modes [:snapshot, :graph]
  @default_mode :snapshot
  @pins [:expected_graph_digest, :expected_snapshot_digest]

  @checkpoint_prefix "urn:semantic-jira:checkpoint:"
  @checkpoint_suffix ~r/\A:[A-Za-z0-9._:-]+\z/

  # Top-level fields the graph side never feeds into a digest
  # (GgenIgniter.SemanticJira.drop_digest_fields/1).
  @digest_fields ~w(work_order_digest transition_digest evidence_digest receipt_digest
                    experience_digest repair_digest finding_digest composition_digest)
  # Extra fields dropped for the stable definition identity
  # (GgenIgniter.SemanticJira.definition_digest/1).
  @definition_fields ~w(standing dimensions)

  @type mode :: :snapshot | :graph
  @type options :: %{
          binding: mode(),
          expected_graph_digest: String.t() | nil,
          expected_snapshot_digest: String.t() | nil
        }

  @doc "Accepted binding modes."
  @spec modes() :: [mode()]
  def modes, do: @modes

  @doc "The fail-closed mode used when the caller declares none."
  @spec default_mode() :: mode()
  def default_mode, do: @default_mode

  @doc """
  Validates the caller's binding options (`:binding`, `:expected_graph_digest`,
  `:expected_snapshot_digest`); everything else in `opts` is ignored.
  """
  @spec options(keyword()) :: {:ok, options()} | {:error, {:refused_semantic_work, term()}}
  def options(opts) when is_list(opts) do
    with {:ok, mode} <- mode(Keyword.get(opts, :binding, @default_mode)),
         {:ok, graph} <- pin(opts, :expected_graph_digest),
         {:ok, snapshot} <- pin(opts, :expected_snapshot_digest) do
      {:ok, %{binding: mode, expected_graph_digest: graph, expected_snapshot_digest: snapshot}}
    end
  end

  defp mode(mode) when mode in @modes, do: {:ok, mode}
  defp mode(other), do: refuse({:invalid_binding_option, other})

  defp pin(opts, key) when key in @pins do
    case Keyword.get(opts, key) do
      nil ->
        {:ok, nil}

      value ->
        if valid_digest?(value), do: {:ok, value}, else: refuse({:invalid_expected_digest, key})
    end
  end

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
  builds it) against its anchors under validated `options` (see `options/1`).
  """
  @spec verify(map(), options()) :: :ok | {:error, {:refused_semantic_work, term()}}
  def verify(descriptor, %{binding: mode} = options)
      when is_map(descriptor) and mode in @modes do
    bridge = Map.get(descriptor, :bridge)
    pin_snapshot = Map.get(options, :expected_snapshot_digest)
    pin_graph = Map.get(options, :expected_graph_digest)

    with {:ok, snapshot} <- admitted_snapshot(descriptor),
         {:ok, bridge_digest} <- bridge_digest(bridge),
         :ok <- bind_snapshot(descriptor, snapshot, bridge),
         inband = inband_anchors(snapshot, bridge_digest),
         :ok <- anchors_agree(trusted_anchor(pin_snapshot) ++ inband ++ envelope(descriptor)),
         :ok <- pin_has_anchor(pin_snapshot, inband),
         :ok <- bind_pinned_graph_digest(descriptor, pin_graph) do
      bind_graph_digest(descriptor, inband, mode)
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

  defp inband_anchors(snapshot, bridge_digest) do
    [
      {:admitted_work_order, snapshot && snapshot_digest(snapshot)},
      {:bridge_source_snapshot_digest, bridge_digest}
    ]
    |> Enum.reject(fn {_source, digest} -> is_nil(digest) end)
  end

  defp trusted_anchor(nil), do: []
  defp trusted_anchor(pin), do: [{:expected_snapshot_digest, pin}]

  defp envelope(descriptor) do
    case Map.get(descriptor, :admission_digest) do
      nil -> []
      digest -> [{:admission_digest, digest}]
    end
  end

  defp anchors_agree([]), do: :ok

  defp anchors_agree([{first_source, first} | rest]) do
    case Enum.find(rest, fn {_source, digest} -> digest != first end) do
      nil -> :ok
      {source, _digest} -> refuse({:admission_anchor_disagree, first_source, source})
    end
  end

  # A pin with nothing in the descriptor to compare against is not evidence.
  defp pin_has_anchor(nil, _inband), do: :ok
  defp pin_has_anchor(_pin, []), do: refuse(:admission_anchor_missing)
  defp pin_has_anchor(_pin, _inband), do: :ok

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
        ] ++
          bridge_identity_checks(bridge, snapshot) ++
          [
            {:dependencies, dependencies_match?(descriptor, snapshot)},
            {:checkpoint_iri, checkpoint_matches?(descriptor, snapshot, bridge)},
            {:goal, goal_matches?(descriptor, snapshot)}
          ] ++ bridge_requires_checks(bridge, snapshot)

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

  # Once a snapshot is carried, a bridge that is present must be its projection:
  # a deleted key is a mismatch (the tamperer's cheapest move), not a pass. A
  # wholly absent bridge is the producer's choice (no receipt export exists
  # without it: `SemanticReceipt.export/1` answers `:no_semantic_bridge`).
  defp bridge_identity_checks(%{} = bridge, snapshot) when not is_struct(bridge) do
    [
      {:bridge_identity, field(bridge, :identity) == field(snapshot, :identity)},
      {:bridge_repository, field(bridge, :repository) == field(snapshot, :repository)},
      {:bridge_base_sha, field(bridge, :base_sha) == field(snapshot, :base_sha)},
      {:bridge_definition_digest,
       field(bridge, :definition_digest) == definition_digest(snapshot)},
      {:bridge_subject, field(bridge, :subject) == field(snapshot, :subject)},
      {:bridge_evidence_ceiling,
       agrees?(field(bridge, :evidence_ceiling), field(snapshot, :evidence_ceiling))},
      {:bridge_replay_identity,
       agrees?(field(bridge, :replay_identity), field(snapshot, :replay_identity))}
    ]
  end

  defp bridge_identity_checks(_none, _snapshot), do: []

  # `requires` is what `SemanticReceipt.export/1` reads its required courts from
  # and what suite adapters receive: exactly the snapshot's three lists, no more.
  defp bridge_requires_checks(%{} = bridge, snapshot) when not is_struct(bridge) do
    expected = %{
      "courts" => field(snapshot, :required_courts),
      "acceptance" => field(snapshot, :acceptance),
      "falsifiers" => field(snapshot, :falsifiers)
    }

    ok? =
      case field(bridge, :requires) do
        %{} = requires when not is_struct(requires) ->
          Map.new(requires, fn {key, value} -> {to_string(key), value} end) == expected

        _ ->
          false
      end

    [{:bridge_requires, ok?}]
  end

  defp bridge_requires_checks(_none, _snapshot), do: []

  defp agrees?(nil, _expected), do: true
  defp agrees?(value, expected), do: value == expected

  # The upstream work orders the snapshot names, as IRIs under the descriptor's
  # own work-order IRI prefix.
  defp dependencies_match?(descriptor, snapshot) do
    identity = field(snapshot, :identity)
    iri = Map.get(descriptor, :work_order_iri)
    declared = Map.get(descriptor, :dependencies)
    upstream = field(snapshot, :dependencies)

    if is_binary(identity) and is_binary(iri) and is_list(declared) and is_list(upstream) do
      prefix = String.replace_suffix(iri, identity, "")
      names = Enum.map(upstream, fn dep -> upstream_iri(prefix, dep) end)

      not Enum.any?(names, &is_nil/1) and
        Enum.sort(Enum.map(declared, &dependency_iri/1)) == names |> Enum.uniq() |> Enum.sort()
    else
      false
    end
  end

  defp upstream_iri(prefix, %{} = dep) when not is_struct(dep) do
    case field(dep, :upstream) do
      name when is_binary(name) and name != "" -> prefix <> name
      _ -> nil
    end
  end

  defp upstream_iri(_prefix, _dep), do: nil

  defp dependency_iri(%{} = dep) when not is_struct(dep), do: field(dep, :work_order_iri)
  defp dependency_iri(_dep), do: nil

  defp checkpoint_matches?(descriptor, snapshot, bridge) do
    iri = Map.get(descriptor, :checkpoint_iri)
    identity = field(snapshot, :identity)
    digest = field(snapshot, :work_order_digest)

    bases =
      [@checkpoint_prefix <> to_string(identity) <> "@" <> to_string(digest)] ++
        ledger_base(bridge)

    is_binary(iri) and Enum.any?(bases, &checkpoint_under?(iri, &1))
  end

  defp ledger_base(%{} = bridge) when not is_struct(bridge) do
    case field(bridge, :ledger_tail) do
      tail when is_binary(tail) and tail != "" -> [@checkpoint_prefix <> tail]
      _ -> []
    end
  end

  defp ledger_base(_none), do: []

  defp checkpoint_under?(iri, base) do
    iri == base or
      (String.starts_with?(iri, base) and
         Regex.match?(
           @checkpoint_suffix,
           binary_part(iri, byte_size(base), byte_size(iri) - byte_size(base))
         ))
  end

  defp goal_matches?(descriptor, snapshot) do
    goal = Map.get(descriptor, :goal)
    is_binary(goal) and goal in goal_projections(snapshot)
  end

  defp goal_projections(snapshot) do
    Enum.reject([driver_goal(snapshot), graph_goal(snapshot)], &is_nil/1)
  end

  # docs/sjira/v26.9.21/e2e_project.exs
  defp driver_goal(snapshot) do
    title = field(snapshot, :title)
    description = field(snapshot, :description)

    if is_binary(title) and is_binary(description), do: title <> ": " <> description
  end

  # GgenIgniter.SemanticJira.Descriptor.goal/1
  defp graph_goal(snapshot) do
    identity = field(snapshot, :identity)
    title = field(snapshot, :title)
    description = field(snapshot, :description)
    acceptance = field(snapshot, :acceptance)
    falsifiers = field(snapshot, :falsifiers)
    scope = field(snapshot, :path_scope)

    if Enum.all?([identity, title, description], &is_binary/1) and
         Enum.all?([acceptance, falsifiers, scope], &is_list/1) do
      Enum.join(
        Enum.concat([
          ["#{identity}: #{title}", "", description, "", "Acceptance:"],
          Enum.map(acceptance, &"- #{&1}"),
          ["", "Falsifiers:"],
          Enum.map(falsifiers, &"- #{&1}"),
          scope_lines(scope)
        ]),
        "\n"
      )
    end
  end

  defp scope_lines([]), do: []
  defp scope_lines(scope), do: ["", "Path scope:" | Enum.map(scope, &"- #{&1}")]

  # -- graph_digest binding --------------------------------------------------

  defp bind_pinned_graph_digest(_descriptor, nil), do: :ok

  defp bind_pinned_graph_digest(descriptor, pin) do
    if Map.get(descriptor, :graph_digest) == pin,
      do: :ok,
      else: refuse({:graph_digest_unbound, :expected_graph_digest, pin})
  end

  defp bind_graph_digest(_descriptor, _inband, :graph), do: :ok

  defp bind_graph_digest(_descriptor, [], :snapshot), do: refuse(:admission_anchor_missing)

  defp bind_graph_digest(descriptor, [{source, expected} | _rest], :snapshot) do
    if Map.get(descriptor, :graph_digest) == expected,
      do: :ok,
      else: refuse({:graph_digest_unbound, source, expected})
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
