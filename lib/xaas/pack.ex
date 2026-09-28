defmodule Xaas.Pack do
  @moduledoc """
  Capability pack court: the smallest executable `Pack -> ggen -> XaaS -> BRCE
  -> Receipt` step.

      pinned pack bytes (ontology.ttl + one profile + gates/*.rq)
        -> content digest vs. the out-of-band pin (config :capability_pack_pins)
        -> ggen: GgenIgniter.Pack.discover_queries/1 gates run by GgenIgniter.Query
        -> XaaS court: SemanticDrive.anchor_from/2 WorkOrder anchor, declaration
           standing, MachineExperience.within_bounds?/2 fit, WorkOrder DO ceiling
        -> BRCE: Xaas.Actuation.run/4 (the one admitted DO kernel), explicit
           caller authority, stable idempotency key
        -> Receipt: canonical-JSON sealed map (Xaas.Tunnel.Receipt.digest/1)

  ## A pack is evidence, never authority

  * `xcp:confers` must be `"NONE"`; anything else is unloadable.
  * The pack's own passport ceiling is judged by
    `Xaas.Ultracode.SubstitutionCourt.validate_authority/1`: DO in a pack is
    `:do_authority_laundering`.
  * The work authority bound comes only from the WorkOrder tuple (its
    `authority_ceiling` must be `"DO"` for an ADMITTED binding) plus the
    caller's VERIFIED authority evidence. A caller map carrying
    `"pack_binding"` is refused; the map minus `"pack_binding"` must be
    non-empty and carry a `"kind"` in the closed set `authority_kinds/0`.
  * A kind label is never authority. `actuate/5` verifies the evidence behind
    it against the admitted `{resource, action}` and subject; the only
    verifier is `maker_checker_approval` for `Xaas.Marketplace.Provider
    :actuate_status`: `"approval_id"` must resolve to a persisted, APPROVED
    `Xaas.Marketplace.ApprovalProviderStatusChange` whose `provider_id` is the
    WorkOrder's subject and whose `requested_status` is the input; every other
    caller-claimed field must equal the record. The recorded authority, the
    kernel input and the idempotency key are re-derived from the record by
    `ApplyProviderStatusChange.authority/1` / `idempotency_key/1` (the
    approval's own producer), so one approval is at most one DO: the approval
    normally already ran it, and the pack receipt is a receipted replay of
    that consequence. Any other kind/binding is
    `{:authority_evidence_unverified, kind, reason}`.
    `ultracode_lease_actuation` is not admitted here: its only lawful producer
    is `Xaas.Ultracode.Lease.actuate/2` (live lease + registry-supplied
    subject) and this court cannot verify a lease without its token.
  * The receipt's `"authority"` is the authority recorded on the
    `ActuationIntent` (the one the consequence ran under); pack identity and
    digest ride on `"evidence"`, never on `"authority"`.

  ## Object-level binding

  The Ash subject is derived from the WorkOrder: exactly one `path_scope`
  entry `"resource:<Resource>/<primary key>"` of the bound resource. It is the
  `WorkIdentity.exact_subject`, it must match the approval's `provider_id`,
  and a caller `:subject_id` that differs is refused. One WorkOrder therefore
  names one subject; a WorkOrder cannot be pointed at another row.

  ## Reuse (and the one exact falsifier where reuse was impossible)

  * WorkOrder anchor: `Xaas.Ultracode.SemanticDrive.anchor_from/2`; its
    `{:refused, map}` is returned unchanged.
  * Work identity / provider exclusion: `SubstitutionCourt.work_identity_digest/1`
    over a `WorkIdentity` (work order, exact subject, origin authority,
    consequence schema = the resource's public-ontology projection hash,
    receipt schema, execution manifest = the Route tuple digest). The pack and
    any provider are excluded from work identity by construction.
  * Fit: `MachineExperience.consequence_bounds/1` + `within_bounds?/2`, with the
    bound's authority ceiling taken from the WorkOrder itself (pack confers none).
  * Pack resolution: `GgenIgniter.Pack.default_ontology/1` and
    `discover_queries/1`; gates run through `GgenIgniter.Query.run/2`.
  * Digest: `Xaas.Tunnel.Receipt.digest/1`.
  * TTL loading follows the `Xaas.Tunnel.Capabilities` pattern (TTL is the
    source of truth, handwritten gate, drift test with anti-vacuity mutation in
    `test/xaas/pack/pack_ontology_test.exs`), NOT `MachineExperience.load/1`.
    Falsifier for `MachineExperience.load/1` (and `GgenIgniter.Ontology.load!/1`):
    both take paths and re-read the files, so a file replaced between the pin
    check and the parse would be admitted under the pin (TOCTOU). Here the
    bytes are read once; the digest and the parse consume the same bytes.
  * DO binding: the pack declares `{resource, action}`; the court verifies at
    load that the action exists and is fenced by
    `Xaas.Actuation.Validations.ReactorContext`, and `admit/3` re-derives the
    pack from its pin on every call (a hand-built or edited struct is
    `{:pack_struct_mismatch, name}`). It is NOT a second actuation registry:
    `Xaas.Ultracode.Lease` never reads it (ROADMAP.md forbids duplicate
    capability/authority planes), and admission here grants nothing
    `Xaas.Actuation.run/4`'s own admission court would not independently judge.
  * Seven facets (`facets/0`) are pack facets mapped onto existing ROADMAP.md
    major planes (1..9), not new planes.

  ## Idempotency and replay

  The key is the verified authority's own key
  (`"approval-provider-status-change:" <> approval_id`): one approval, one
  (subject, input) consequence. The kernel fingerprints subject and input into
  the input hash, and the evidence check already refuses a subject or input
  the approval does not name. A replay whose recorded
  `ActuationIntent.authority` differs from the authority verified now (e.g.
  the approval was re-approved by another checker after its DO) is
  `{:refused, :replay_authority_mismatch}`; the receipt never names an
  authority the consequence did not run under.

  `graph_digest` is caller-asserted: it is bound into the anchor's request
  digest and the receipt evidence (`"graph_digest_standing" =>
  "CALLER_ASSERTED"`), but not re-derived from a graph here (the live
  derivation is `SemanticDrive.anchor/1`), and it is excluded from the work
  identity and the idempotency key.

  ## Residue

  HANDWRITTEN.md: UNSUPPORTED(generator-capability) -- ggen_igniter renders
  data projections from a pack (the `lib/xaas/generated/zcode_event_registry.ex`
  precedent) but no admitted pack renders admission-court decisions; this
  module reads its data from the pinned TTL at runtime (no handwritten copy of
  the declarations) and `generator_residue/0` is the typed receipt for the
  decision-logic gap. `Xaas.Generation.ResidueRegistry` does not apply: no
  generated file is hand-patched.
  """

  alias GgenIgniter.Pack, as: GgenPack
  alias GgenIgniter.Query
  alias Xaas.Actuation.Validations.ReactorContext
  alias Xaas.Generation.UnsupportedReceipt
  alias Xaas.Marketplace.{ApprovalProviderStatusChange, Provider}
  alias Xaas.Marketplace.Changes.ApplyProviderStatusChange
  alias Xaas.Semantics.Registry
  alias Xaas.Tunnel.Receipt
  alias Xaas.Ultracode.{MachineExperience, SemanticDrive, SubstitutionCourt}
  alias Xaas.Ultracode.SubstitutionCourt.WorkIdentity

  @schema "xaas.capability-pack/1"
  @receipt_schema "xaas.capability-pack-receipt/1"
  @xcp "https://xaas.dev/ontology/capability-pack#"
  @skos "http://www.w3.org/2004/02/skos/core#"
  @owl "http://www.w3.org/2002/07/owl#"
  @close_match @skos <> "closeMatch"
  @alignment_predicates [
    @skos <> "closeMatch",
    @skos <> "exactMatch",
    @skos <> "broadMatch",
    @skos <> "narrowMatch",
    @skos <> "relatedMatch",
    @owl <> "equivalentClass",
    @owl <> "equivalentProperty",
    @owl <> "sameAs"
  ]
  @standings ~w(ADMITTED REFUSED UNSUPPORTED)
  @required_gates ~w(declarations pack)
  @authority_kinds ~w(maker_checker_approval)
  @roadmap_planes 1..9
  @facets %{
    "OntologyFacet" => 1,
    "GenerationFacet" => 2,
    "CapabilityFacet" => 6,
    "AuthorityFacet" => 7,
    "ConsequenceFacet" => 7,
    "DeliveryFacet" => 7,
    "ReceiptFacet" => 8
  }
  @ceiling_atoms %{
    "observe" => :observe,
    "select" => :select,
    "construct" => :construct,
    "do" => :do
  }
  @capability ~r/\A[a-z0-9][a-z0-9_.-]*:[a-z0-9][a-z0-9_.:-]*\z/
  @digest ~r/\Asha256:[0-9a-f]{64}\z/

  defstruct [
    :name,
    :pack_dir,
    :profile,
    :digest,
    :pack_id,
    :confers,
    pinned?: false,
    authority_ceiling: [],
    facets: %{},
    alignments: [],
    declarations: %{}
  ]

  @type t :: %__MODULE__{}
  @type refusal :: {:refused, term()}

  @doc "The seven pack facets (local name in `xcp:`) and the ROADMAP.md plane each maps onto."
  @spec facets() :: %{String.t() => pos_integer()}
  def facets, do: @facets

  @doc "Closed set of caller authority kinds `authority_context/1` admits."
  @spec authority_kinds() :: [String.t()]
  def authority_kinds, do: @authority_kinds

  @doc "The typed generator-capability residue receipt for this handwritten court."
  @spec generator_residue() :: UnsupportedReceipt.t()
  def generator_residue do
    UnsupportedReceipt.build(
      "ggen_igniter",
      :admission_court_not_derivable,
      "ggen_igniter renders data projections from a pack; no admitted pack renders the " <>
        "Xaas.Pack admission decisions (pin, canonical form, alignment, fence, fit, authority)"
    )
  end

  # ---------------------------------------------------------------------------
  # Pack -> (pin) -> ggen
  # ---------------------------------------------------------------------------

  @doc """
  Loads the pack pinned as `name` in `config :xaas, :capability_pack_pins`
  (`%{name => %{pack: dir under priv/packs, profile: path in the pack, digest:
  "sha256:..."}}`). The content digest of the bytes read must equal the
  committed pin, else `{:refused, {:pack_digest_mismatch, pinned, observed}}`.
  `opts[:pack_dir]` reads the pack from another directory under the SAME pin.
  """
  @spec load(String.t(), keyword()) :: {:ok, t()} | refusal()
  def load(name, opts \\ []) when is_binary(name) do
    with {:ok, pin} <- pin(name),
         pack_dir = Keyword.get(opts, :pack_dir, default_dir(pin.pack)),
         {:ok, files} <- read_files(pack_dir, pin.profile),
         observed = digest_of(files),
         :ok <- pinned_digest(pin.digest, observed),
         {:ok, pack} <- build(files, pack_dir, pin.profile, observed) do
      {:ok, %{pack | name: name, pinned?: true}}
    end
  end

  @doc """
  Reads and judges a pack WITHOUT a pin (`pinned?: false`). An unpinned pack is
  never admitted for actuation (`{:refused, :pack_not_pinned}`).
  """
  @spec read(String.t(), String.t()) :: {:ok, t()} | refusal()
  def read(pack_dir, profile) when is_binary(pack_dir) and is_binary(profile) do
    with {:ok, files} <- read_files(pack_dir, profile) do
      build(files, pack_dir, profile, digest_of(files))
    end
  end

  @doc "The content digest of `ontology.ttl`, `profile` and `gates/*.rq` under `pack_dir`."
  @spec digest(String.t(), String.t()) :: {:ok, String.t()} | refusal()
  def digest(pack_dir, profile) do
    with {:ok, files} <- read_files(pack_dir, profile), do: {:ok, digest_of(files)}
  end

  defp pin(name) do
    case :xaas |> Application.get_env(:capability_pack_pins, %{}) |> Map.get(name) do
      %{pack: pack, profile: profile, digest: digest} = pin
      when is_binary(pack) and is_binary(profile) and is_binary(digest) ->
        if Regex.match?(@digest, digest),
          do: {:ok, pin},
          else: {:refused, {:pack_pin_invalid, name}}

      nil ->
        {:refused, {:pack_unpinned, name}}

      _other ->
        {:refused, {:pack_pin_invalid, name}}
    end
  end

  defp default_dir(pack), do: Application.app_dir(:xaas, Path.join("priv/packs", pack))

  defp pinned_digest(digest, digest), do: :ok
  defp pinned_digest(pinned, observed), do: {:refused, {:pack_digest_mismatch, pinned, observed}}

  defp read_files(pack_dir, profile) do
    ontology = GgenPack.default_ontology(pack_dir)
    gates = GgenPack.discover_queries(pack_dir)

    paths =
      [{:ontology, ontology}, {:profile, Path.join(pack_dir, profile)}] ++
        Enum.map(gates, fn {name, path} -> {{:gate, name}, path} end)

    Enum.reduce_while(paths, {:ok, []}, fn {role, path}, {:ok, acc} ->
      case File.read(path) do
        {:ok, bytes} ->
          {:cont,
           {:ok, [%{role: role, rel: Path.relative_to(path, pack_dir), bytes: bytes} | acc]}}

        {:error, reason} ->
          {:halt,
           {:refused, {:pack_unloadable, {:unreadable, Path.relative_to(path, pack_dir), reason}}}}
      end
    end)
    |> case do
      {:ok, files} -> {:ok, Enum.reverse(files)}
      refused -> refused
    end
  end

  defp digest_of(files) do
    body = %{
      "schema" => @schema,
      "files" =>
        Map.new(files, fn %{rel: rel, bytes: bytes} ->
          {rel, :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)}
        end)
    }

    "sha256:" <> Receipt.digest(body)
  end

  defp build(files, pack_dir, profile, digest) do
    with {:ok, graph} <- parse(files),
         :ok <- canonical(graph),
         {:ok, alignments} <- alignments(graph),
         {:ok, gates} <- gates(files),
         {:ok, node} <- pack_node(Query.run(graph, gates["pack"])),
         {:ok, declarations} <- declarations(Query.run(graph, gates["declarations"]), node.facets) do
      {:ok,
       %__MODULE__{
         pack_dir: pack_dir,
         profile: profile,
         digest: digest,
         pack_id: node.pack_id,
         confers: node.confers,
         authority_ceiling: node.authority_ceiling,
         facets: node.facets,
         alignments: alignments,
         declarations: declarations
       }}
    end
  end

  defp parse(files) do
    files
    |> Enum.filter(&(&1.role in [:ontology, :profile]))
    |> Enum.reduce_while({:ok, RDF.Graph.new()}, fn %{rel: rel, bytes: bytes}, {:ok, acc} ->
      case RDF.Turtle.read_string(bytes) do
        {:ok, graph} ->
          {:cont, {:ok, RDF.Graph.add(acc, graph)}}

        {:error, error} ->
          {:halt, {:refused, {:pack_unloadable, {:unparseable, rel, inspect(error)}}}}
      end
    end)
  end

  # No blank nodes: every node is an IRI, so the graph has one canonical form
  # and every declaration is addressable.
  defp canonical(graph) do
    graph
    |> RDF.Graph.triples()
    |> Enum.find_value(:ok, fn {s, _p, o} ->
      Enum.find_value([s, o], fn
        %RDF.BlankNode{} = node ->
          {:refused, {:pack_unloadable, {:non_canonical_value, to_string(node)}}}

        _ ->
          nil
      end)
    end)
  end

  # Alignment is projected; only skos:closeMatch is admitted (non-transitive,
  # imports no semantics, so it can launder neither class membership nor authority).
  defp alignments(graph) do
    graph
    |> RDF.Graph.triples()
    |> Enum.filter(fn {_s, p, _o} -> to_string(p) in @alignment_predicates end)
    |> Enum.map(fn {s, p, o} -> {to_string(s), to_string(p), to_string(o)} end)
    |> Enum.sort()
    |> Enum.reduce_while({:ok, []}, fn
      {s, @close_match, o}, {:ok, acc} ->
        {:cont, {:ok, [%{"subject" => s, "predicate" => @close_match, "object" => o} | acc]}}

      {_s, p, o}, _acc ->
        {:halt, {:refused, {:pack_unloadable, {:non_close_match_alignment, p, o}}}}
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      refused -> refused
    end
  end

  defp gates(files) do
    gates = for %{role: {:gate, name}, bytes: bytes} <- files, into: %{}, do: {name, bytes}

    case Enum.find(@required_gates, &(not Map.has_key?(gates, &1))) do
      nil -> {:ok, gates}
      missing -> {:refused, {:pack_unloadable, {:gate_missing, missing}}}
    end
  end

  defp pack_node(rows) do
    case group(rows, "pack") do
      [{iri, values}] ->
        with {:ok, pack_id} <- single(values, iri, "packId"),
             {:ok, confers} <- single(values, iri, "confers"),
             :ok <- confers_none(confers),
             ceiling =
               values |> set("authorityCeiling") |> Enum.map(&Map.get(@ceiling_atoms, &1, &1)),
             :ok <- ceiling_law(ceiling),
             {:ok, facets} <- facet_planes(rows) do
          {:ok, %{pack_id: pack_id, confers: confers, authority_ceiling: ceiling, facets: facets}}
        end

      nodes ->
        {:refused, {:pack_unloadable, {:pack_node_count, length(nodes)}}}
    end
  end

  defp confers_none("NONE"), do: :ok
  defp confers_none(other), do: {:refused, {:pack_unloadable, {:pack_confers_authority, other}}}

  defp ceiling_law(ceiling) do
    case SubstitutionCourt.validate_authority(ceiling) do
      :ok -> :ok
      {:error, reason} -> {:refused, {:pack_unloadable, reason}}
    end
  end

  defp facet_planes(rows) do
    rows
    |> Enum.filter(&(is_binary(&1["facet"]) and not is_nil(&1["plane"])))
    |> Enum.map(&{local(&1["facet"]), &1["plane"]})
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, %{}}, fn {facet, plane}, {:ok, acc} ->
      cond do
        not (is_integer(plane) and plane in @roadmap_planes) ->
          {:halt, {:refused, {:pack_unloadable, {:facet_outside_roadmap_planes, facet, plane}}}}

        Map.has_key?(acc, facet) ->
          {:halt, {:refused, {:pack_unloadable, {:ambiguous_value, facet, "roadmapPlane"}}}}

        true ->
          {:cont, {:ok, Map.put(acc, facet, plane)}}
      end
    end)
  end

  defp declarations(rows, facets) do
    rows
    |> group("declaration")
    |> Enum.reduce_while({:ok, %{}}, fn {iri, values}, {:ok, acc} ->
      case declaration(iri, values, facets) do
        {:ok, %{"capability" => capability} = decl} ->
          if Map.has_key?(acc, capability),
            do: {:halt, {:refused, {:pack_unloadable, {:duplicate_capability, capability}}}},
            else: {:cont, {:ok, Map.put(acc, capability, decl)}}

        refused ->
          {:halt, refused}
      end
    end)
  end

  defp declaration(iri, values, facets) do
    with {:ok, capability} <- single(values, iri, "capability"),
         :ok <- canonical_capability(capability),
         {:ok, standing} <- single(values, iri, "standing"),
         :ok <- known_standing(capability, standing),
         {:ok, facet} <- single(values, iri, "facet"),
         :ok <- declared_facet(capability, local(facet), facets),
         {:ok, tool} <- optional(values, iri, "tool") do
      base = %{
        "iri" => iri,
        "capability" => capability,
        "standing" => standing,
        "facet" => local(facet),
        "tool" => tool
      }

      standing_fields(standing, base, values)
    end
  end

  # Resource/action rules apply only to ADMITTED entries; REFUSED/UNSUPPORTED
  # carry a refusalReason only (any resource/action on them is not resolved).
  defp standing_fields("ADMITTED", %{"capability" => capability} = base, values) do
    with {:ok, resource} <- required(values, capability, "resource"),
         {:ok, action} <- required(values, capability, "action"),
         {:ok, class} <- required(values, capability, "consequenceClass"),
         scope when scope != [] <- set(values, "pathScope"),
         {:ok, module} <- resolve_resource(resource),
         {:ok, action_atom} <- fenced_action(module, resource, action) do
      {:ok,
       Map.merge(base, %{
         "resource" => module,
         "action" => action_atom,
         "consequence_class" => class,
         "path_scope" => Enum.sort(scope),
         "required_exclusions" => values |> set("requiredExclusion") |> Enum.sort()
       })}
    else
      [] -> {:refused, {:pack_unloadable, {:declaration_incomplete, capability, "pathScope"}}}
      refused -> refused
    end
  end

  defp standing_fields(_refused_or_unsupported, %{"capability" => capability} = base, values) do
    with {:ok, reason} <- required(values, capability, "refusalReason") do
      {:ok, Map.put(base, "refusal_reason", reason)}
    end
  end

  defp resolve_resource(name) do
    module = Module.safe_concat([name])

    if Code.ensure_loaded?(module) and Ash.Resource.Info.resource?(module),
      do: {:ok, module},
      else: {:refused, {:pack_unloadable, {:unknown_resource, name}}}
  rescue
    ArgumentError -> {:refused, {:pack_unloadable, {:unknown_resource, name}}}
  end

  defp fenced_action(module, resource, action) do
    atom = String.to_existing_atom(action)

    case Ash.Resource.Info.action(module, atom) do
      nil ->
        {:refused, {:pack_unloadable, {:unknown_action, resource, action}}}

      definition ->
        if reactor_fenced?(definition),
          do: {:ok, atom},
          else: {:refused, {:pack_unloadable, {:action_not_fenced, resource, action}}}
    end
  rescue
    ArgumentError -> {:refused, {:pack_unloadable, {:unknown_action, resource, action}}}
  end

  defp reactor_fenced?(definition) do
    (List.wrap(Map.get(definition, :changes)) ++ List.wrap(Map.get(definition, :validations)))
    |> Enum.any?(fn
      %{module: ReactorContext} -> true
      %{validation: {ReactorContext, _opts}} -> true
      _ -> false
    end)
  end

  defp canonical_capability(capability) do
    if Regex.match?(@capability, capability),
      do: :ok,
      else: {:refused, {:pack_unloadable, {:invalid_capability, capability}}}
  end

  defp known_standing(_capability, standing) when standing in @standings, do: :ok

  defp known_standing(capability, standing),
    do: {:refused, {:pack_unloadable, {:invalid_standing, capability, standing}}}

  defp declared_facet(capability, facet, facets) do
    if Map.has_key?(facets, facet),
      do: :ok,
      else: {:refused, {:pack_unloadable, {:undeclared_facet, capability, facet}}}
  end

  # -- gate rows ------------------------------------------------------------------

  defp group(rows, key) do
    rows
    |> Enum.group_by(& &1[key])
    |> Enum.map(fn {iri, grouped} -> {to_string(iri), grouped} end)
    |> Enum.sort()
  end

  defp set(rows, field) do
    rows |> Enum.map(& &1[field]) |> Enum.reject(&is_nil/1) |> Enum.map(&value/1) |> Enum.uniq()
  end

  defp single(rows, subject, field) do
    case set(rows, field) do
      [value] -> {:ok, value}
      [] -> {:refused, {:pack_unloadable, {:missing_value, subject, field}}}
      _many -> {:refused, {:pack_unloadable, {:ambiguous_value, subject, field}}}
    end
  end

  defp optional(rows, subject, field) do
    case set(rows, field) do
      [] -> {:ok, nil}
      _one -> single(rows, subject, field)
    end
  end

  defp required(rows, capability, field) do
    case single(rows, capability, field) do
      {:ok, value} -> {:ok, value}
      {:refused, {:pack_unloadable, {:missing_value, _, _}}} -> incomplete(capability, field)
      refused -> refused
    end
  end

  defp incomplete(capability, field),
    do: {:refused, {:pack_unloadable, {:declaration_incomplete, capability, field}}}

  defp value(%RDF.BlankNode{} = node), do: to_string(node)
  defp value(other) when is_binary(other) or is_integer(other), do: other
  defp value(other), do: to_string(other)

  defp local(iri) when is_binary(iri) do
    if String.starts_with?(iri, @xcp), do: String.replace_prefix(iri, @xcp, ""), else: iri
  end

  # ---------------------------------------------------------------------------
  # XaaS court
  # ---------------------------------------------------------------------------

  @doc """
  Admits sJira WorkOrder `row` (snake_case keys, `requires_capability`, ...)
  against a PINNED pack under the caller-asserted `graph_digest`.

  The struct is never trusted: the pack is re-derived from its pin
  (`load/2` of `pack.name` from `pack.pack_dir`, i.e. the committed digest,
  canonical form and ReactorContext fence are judged again) and the re-derived
  struct must equal the one passed, else
  `{:refused, {:pack_struct_mismatch, name}}`.

  The WorkOrder must name exactly one Ash subject of the bound resource in its
  `path_scope` as `"resource:<Resource>/<primary key>"`; for the fit the entry
  counts as its class entry `"resource:<Resource>"`. The subject is derived
  from the WorkOrder, never from the caller.

  Refusals: `SemanticDrive.anchor_from/2`'s `{:refused, map}` unchanged;
  `{:refused, :pack_not_pinned}`; `{:refused, {:pack_struct_mismatch, name}}`
  (plus `load/2`'s refusals); `{:refused, {:capability_not_declared, c}}`;
  `{:refused, {:capability_refused, c, reason}}`;
  `{:unsupported, {:capability_unsupported, c, reason}}`;
  `{:refused, {:authority_ceiling_insufficient, ceiling}}` (an ADMITTED binding
  is a DO; the WorkOrder's own ceiling must be `"DO"`);
  `{:refused, {:consequence_out_of_bounds, bounds}}`;
  `{:refused, :work_order_subject_missing}`;
  `{:refused, {:work_order_subject_ambiguous, entries}}`;
  `{:refused, {:work_order_subject_invalid, entry}}`.
  """
  @spec admit(t(), map(), term()) :: {:ok, map()} | refusal() | {:unsupported, term()}
  def admit(%__MODULE__{pinned?: true, name: name} = pack, %{} = row, graph_digest)
      when is_binary(name) do
    with {:ok, pack} <- repinned(pack),
         {:ok, anchor} <- SemanticDrive.anchor_from(row, graph_digest),
         tuple = anchor["tuple"],
         {:ok, decl} <- declared(pack, tuple["capability"]),
         :ok <- do_ceiling(tuple["authority_ceiling"]),
         bounds = bounds(decl, tuple),
         {subjects, scope} = split_scope(decl, row),
         :ok <- fit(bounds, Map.put(row, "path_scope", scope)),
         {:ok, subject} <- work_subject(decl, subjects),
         {:ok, work} <- work_identity(decl, anchor, subject) do
      {:ok,
       %{
         "pack" => pack.name,
         "pack_digest" => pack.digest,
         "profile" => pack.profile,
         "capability" => decl["capability"],
         "resource" => decl["resource"],
         "action" => decl["action"],
         "subject" => subject.entry,
         "subject_id" => subject.id,
         "anchor" => anchor,
         "graph_digest" => graph_digest,
         "bounds" => bounds,
         "authority_bound" => tuple["authority_ceiling"],
         "pack_confers" => pack.confers,
         "work_identity_digest" => SubstitutionCourt.work_identity_digest(work)
       }}
    end
  end

  def admit(%__MODULE__{}, _row, _graph_digest), do: {:refused, :pack_not_pinned}

  # The pin, not the struct, decides: every field of the struct must be what
  # the committed pin re-derives from the bytes on disk right now.
  defp repinned(%__MODULE__{name: name, pack_dir: dir} = pack) when is_binary(dir) do
    case load(name, pack_dir: dir) do
      {:ok, ^pack} -> {:ok, pack}
      {:ok, %__MODULE__{}} -> {:refused, {:pack_struct_mismatch, name}}
      refused -> refused
    end
  end

  defp repinned(%__MODULE__{name: name}), do: {:refused, {:pack_struct_mismatch, name}}

  defp declared(pack, capability) do
    case Map.get(pack.declarations, capability) do
      %{"standing" => "ADMITTED"} = decl ->
        {:ok, decl}

      %{"standing" => "REFUSED", "refusal_reason" => reason} ->
        {:refused, {:capability_refused, capability, reason}}

      %{"standing" => "UNSUPPORTED", "refusal_reason" => reason} ->
        {:unsupported, {:capability_unsupported, capability, reason}}

      nil ->
        {:refused, {:capability_not_declared, capability}}
    end
  end

  defp do_ceiling("DO"), do: :ok
  defp do_ceiling(ceiling), do: {:refused, {:authority_ceiling_insufficient, ceiling}}

  # The pack contributes class, scope and required exclusions; the authority
  # ceiling of the bound is the WorkOrder's own (pack confers none).
  defp bounds(decl, tuple) do
    MachineExperience.consequence_bounds(%{
      "authority_ceiling" => tuple["authority_ceiling"],
      "consequence_class" => decl["consequence_class"],
      "path_scope" => decl["path_scope"],
      "exclusions" => decl["required_exclusions"]
    })
  end

  defp fit(bounds, row) do
    if MachineExperience.within_bounds?(bounds, row),
      do: :ok,
      else: {:refused, {:consequence_out_of_bounds, bounds}}
  end

  # Subject entries ("resource:<Resource>/<pk>") of the bound resource are
  # split out; for the fit each counts as its class entry.
  defp split_scope(decl, row) do
    class = "resource:" <> inspect(decl["resource"])
    prefix = class <> "/"

    {subjects, scope} =
      row
      |> Map.get("path_scope", [])
      |> List.wrap()
      |> Enum.split_with(&(is_binary(&1) and String.starts_with?(&1, prefix)))

    {Enum.uniq(subjects), if(subjects == [], do: scope, else: Enum.uniq(scope ++ [class]))}
  end

  defp work_subject(decl, [entry]) do
    id = String.replace_prefix(entry, "resource:" <> inspect(decl["resource"]) <> "/", "")

    with [pk] <- Ash.Resource.Info.primary_key(decl["resource"]),
         %{type: type, constraints: constraints} <-
           Ash.Resource.Info.attribute(decl["resource"], pk),
         {:ok, value} when not is_nil(value) <- Ash.Type.cast_input(type, id, constraints) do
      {:ok, %{entry: entry, id: to_string(value)}}
    else
      _ -> {:refused, {:work_order_subject_invalid, entry}}
    end
  end

  defp work_subject(_decl, []), do: {:refused, :work_order_subject_missing}

  defp work_subject(_decl, many),
    do: {:refused, {:work_order_subject_ambiguous, Enum.sort(many)}}

  # exact_subject is the Ash subject the DO touches; the sJira subject is in
  # the tuple digest (execution manifest).
  defp work_identity(decl, anchor, subject) do
    case Registry.admit(decl["resource"]) do
      {:ok, projection} ->
        {:ok,
         %WorkIdentity{
           work_order_id: anchor["work_order"],
           exact_subject: subject.entry,
           origin_authority: anchor["tuple"]["authority_ceiling"],
           consequence_schema_digest: "sha256:" <> Registry.hash(projection),
           receipt_schema_digest: "sha256:" <> Receipt.digest(%{"schema" => @receipt_schema}),
           execution_manifest_digest: anchor["tuple_digest"]
         }}

      {:error, reason} ->
        {:refused, {:resource_not_admitted, inspect(decl["resource"]), reason}}
    end
  end

  # ---------------------------------------------------------------------------
  # authority
  # ---------------------------------------------------------------------------

  @doc """
  The shape check of the caller's authority REQUEST (evidence is verified
  later, in `actuate/5`, against the admitted binding). The pack is never
  authority: `{:refused, :authority_missing}` when the caller map minus
  `"pack_binding"` is empty (or not a map), `{:refused,
  :pack_binding_is_not_authority}` when it carries `"pack_binding"`,
  `{:refused, {:authority_kind_not_admitted, kind}}` when `"kind"` is not in
  `authority_kinds/0`. Keys are normalized to strings.
  """
  @spec authority_context(term()) :: {:ok, map()} | refusal()
  def authority_context(%{} = caller) when not is_struct(caller) do
    authority = Map.new(caller, fn {key, value} -> {key_string(key), value} end)
    rest = Map.delete(authority, "pack_binding")

    cond do
      map_size(rest) == 0 -> {:refused, :authority_missing}
      Map.has_key?(authority, "pack_binding") -> {:refused, :pack_binding_is_not_authority}
      authority["kind"] in @authority_kinds -> {:ok, authority}
      true -> {:refused, {:authority_kind_not_admitted, authority["kind"]}}
    end
  end

  def authority_context(_caller), do: {:refused, :authority_missing}

  defp key_string(key) when is_binary(key), do: key
  defp key_string(key) when is_atom(key), do: Atom.to_string(key)
  defp key_string(key), do: inspect(key)

  # Evidence verification per admitted binding. A kind label is never
  # authority by itself: maker-checker authority for Provider :actuate_status
  # is re-derived from the persisted, APPROVED ApprovalProviderStatusChange,
  # which must name the WorkOrder's subject and the requested input. The
  # authority map, the kernel input and the idempotency key are the ones
  # ApplyProviderStatusChange itself uses, so one approval is at most one DO
  # (normally the approval already ran it and this is a receipted replay).
  defp verify_evidence(
         %{"kind" => "maker_checker_approval" = kind} = request,
         %{"resource" => Provider, "action" => :actuate_status} = admission,
         input
       ) do
    with {:ok, id} <- approval_id(request, kind),
         {:ok, approval} <- approval(id, kind),
         :ok <- evidence(not is_nil(approval.approved_by), kind, :approval_not_approved),
         :ok <-
           evidence(
             to_string(approval.provider_id) == admission["subject_id"],
             kind,
             :subject_mismatch
           ),
         :ok <-
           evidence(
             Receipt.json_safe(input) == %{"status" => to_string(approval.requested_status)},
             kind,
             :input_mismatch
           ),
         authority = Receipt.json_safe(ApplyProviderStatusChange.authority(approval)),
         :ok <- caller_claims(request, authority, kind) do
      {:ok,
       %{
         authority: authority,
         input: %{status: approval.requested_status},
         key: ApplyProviderStatusChange.idempotency_key(approval)
       }}
    end
  end

  defp verify_evidence(%{"kind" => kind}, admission, _input),
    do:
      {:refused,
       {:authority_evidence_unverified, kind,
        {:no_verifier, inspect(admission["resource"]), Atom.to_string(admission["action"])}}}

  defp approval_id(%{"approval_id" => id}, _kind) when is_binary(id) and id != "", do: {:ok, id}

  defp approval_id(_request, kind),
    do: {:refused, {:authority_evidence_unverified, kind, :approval_id_missing}}

  defp approval(id, kind) do
    case Ash.get(ApprovalProviderStatusChange, id, authorize?: false) do
      {:ok, %ApprovalProviderStatusChange{} = approval} -> {:ok, approval}
      _ -> {:refused, {:authority_evidence_unverified, kind, :approval_not_found}}
    end
  end

  defp evidence(true, _kind, _reason), do: :ok

  defp evidence(false, kind, reason),
    do: {:refused, {:authority_evidence_unverified, kind, reason}}

  # Every field the caller claims must be what the record says; nothing the
  # caller adds is recorded as authority.
  defp caller_claims(request, authority, kind) do
    Enum.find_value(request, :ok, fn {key, value} ->
      if Map.has_key?(authority, key) and authority[key] == Receipt.json_safe(value),
        do: nil,
        else: {:refused, {:authority_evidence_unverified, kind, {:claim_mismatch, key}}}
    end)
  end

  # ---------------------------------------------------------------------------
  # BRCE -> Receipt
  # ---------------------------------------------------------------------------

  @doc """
  Admits `row` (`admit/3`), verifies the caller's authority evidence against
  the admitted binding and subject, and runs the bound action ONLY through
  `Xaas.Actuation.run/4` with the verified authority's idempotency key and
  `authorize?: false` + the record-derived authority map. `opts`: `:input` (a
  map); `:subject_id` is optional and, if given, must equal the WorkOrder's
  subject (`{:refused, {:subject_not_in_work_order, given}}`).

  Evidence refusals: `{:refused, {:authority_evidence_unverified, kind,
  reason}}`. A replay whose recorded `ActuationIntent.authority` differs from
  the authority verified now is `{:refused, :replay_authority_mismatch}`; the
  receipt's `"authority"` is always the recorded one (the authority the
  consequence actually ran under).

  `{:ok, receipt}` (sealed, `verify_receipt/1`), any refusal of the court, or
  `{:error, reason}` exactly as `Xaas.Actuation.run/4` returns it.
  """
  @spec actuate(t(), map(), term(), term(), keyword()) ::
          {:ok, map()} | refusal() | {:unsupported, term()} | {:error, term()}
  def actuate(%__MODULE__{} = pack, %{} = row, graph_digest, caller, opts) do
    input = Keyword.get(opts, :input, %{})

    with {:ok, request} <- authority_context(caller),
         :ok <- input_map(input),
         {:ok, admission} <- admit(pack, row, graph_digest),
         :ok <- caller_subject(opts, admission["subject_id"]),
         {:ok, grant} <- verify_evidence(request, admission, input) do
      input_digest = "sha256:" <> Receipt.digest(Receipt.json_safe(grant.input))

      case Xaas.Actuation.run(admission["resource"], admission["action"], grant.input,
             subject_id: admission["subject_id"],
             idempotency_key: grant.key,
             authorize?: false,
             authority: grant.authority
           ) do
        {:ok, envelope} ->
          with :ok <- ran_under(grant.authority, envelope) do
            {:ok, seal(admission, input_digest, grant.key, envelope)}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp input_map(%{} = input) when not is_struct(input), do: :ok
  defp input_map(_input), do: {:refused, :input_not_a_map}

  defp caller_subject(opts, subject_id) do
    case Keyword.fetch(opts, :subject_id) do
      :error ->
        :ok

      {:ok, given} ->
        if Receipt.json_safe(given) == subject_id,
          do: :ok,
          else: {:refused, {:subject_not_in_work_order, Receipt.json_safe(given)}}
    end
  end

  defp ran_under(authority, envelope) do
    if Receipt.json_safe(envelope.intent.authority) == Receipt.json_safe(authority),
      do: :ok,
      else: {:refused, :replay_authority_mismatch}
  end

  defp seal(admission, input_digest, key, envelope) do
    receipt = envelope.receipt
    recorded = Receipt.json_safe(envelope.intent.authority)

    body =
      Receipt.json_safe(%{
        "schema" => @receipt_schema,
        "identity" => %{
          "work_order" => admission["anchor"]["work_order"],
          "work_identity_digest" => admission["work_identity_digest"],
          "tuple_digest" => admission["anchor"]["tuple_digest"],
          "request_digest" => admission["anchor"]["request_digest"],
          "subject" => admission["subject"],
          "subject_id" => admission["subject_id"],
          "input_digest" => input_digest
        },
        "authority" => %{
          "kind" => recorded["kind"],
          "authority_digest" => "sha256:" <> Receipt.digest(recorded),
          "work_authority_bound" => admission["authority_bound"],
          "pack_confers" => admission["pack_confers"]
        },
        "consequence" => %{
          "resource" => inspect(admission["resource"]),
          "action" => Atom.to_string(admission["action"]),
          "actuation_intent_id" => to_string(envelope.intent.id),
          "actuation_receipt_id" => to_string(receipt.id),
          "actuation_status" => to_string(receipt.status),
          "input_hash" => receipt.input_hash,
          "result_hash" => receipt.result_hash,
          "ontology_projection_hash" => receipt.ontology_projection_hash
        },
        "replay" => %{
          "replayed" => envelope.replay? == true,
          "idempotency_key" => key,
          "replay_token" => receipt.replay_token
        },
        "evidence" => %{
          "pack" => admission["pack"],
          "pack_digest" => admission["pack_digest"],
          "profile" => admission["profile"],
          "capability" => admission["capability"],
          "graph_digest" => admission["graph_digest"],
          "graph_digest_standing" => "CALLER_ASSERTED"
        },
        "standing" => if(receipt.status == :succeeded, do: "ALIVE", else: "UNKNOWN")
      })

    Map.put(body, "receipt_sha256", Receipt.digest(body))
  end

  @doc "Replay law: the receipt's `receipt_sha256` must recompute over every other field."
  @spec verify_receipt(term()) :: :ok | {:refused, :replay_digest_mismatch}
  def verify_receipt(%{"receipt_sha256" => declared} = receipt),
    do: Receipt.verify_replay(Map.delete(receipt, "receipt_sha256"), declared)

  def verify_receipt(_receipt), do: {:refused, :replay_digest_mismatch}
end
