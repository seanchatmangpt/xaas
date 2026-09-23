defmodule Xaas.Ultracode.MachineExperience do
  @moduledoc """
  The MachineExperience ratchet (GC-26.9.23 gate GC23-9; PRD PR-014, PR-015,
  PR-016; ARD section 15; lane V23-M): a verified UNKNOWN episode becomes an
  admitted, reusable KNOWN route.

  Everything in this module is deterministic; no model runs here.

  ## Routing (`route/2`)

  An sJira work-order row (the snake_case `work.json` row of
  `Xaas.Ultracode.SemanticDrive`) routes:

    1. KNOWN from its own declared `requires_capability`, when it has one;
    2. otherwise KNOWN from ADMITTED MachineExperience in an RDF graph: an
       `xme:AdmittedExperience` node with `xme:admission "ADMITTED"` whose
       `xme:experience` is a present `sj:MachineExperience` node carrying its
       `sj:experienceDigest`, whose `xme:applicabilityPredicate` (a SPARQL
       SELECT over the order's RDF rendering, `order_graph/1`) selects the
       order, and whose `xme:consequenceBounds` contain the order's authority
       ceiling, consequence class and path scope. The route names the
       experience by IRI and takes the capability from the graph's
       `xme:admittedCapability` -- never from a literal in code or in the
       order;
    3. otherwise UNKNOWN (`no_capability_no_experience`), or UNKNOWN
       (`ambiguous_experience`) when applicable experiences name different
       capabilities.

  Removing the `sj:MachineExperience` node (or its admission) from the graph
  turns a KNOWN route UNKNOWN: the route exists only because the admitted
  experience does.

  ## Manufacture (`generalize/1`, `experience_attrs/3`, `to_turtle/2`)

  After an UNKNOWN episode's exploration candidate is driven to ALIVE, the
  ARD section 15 fields are derived from the source order and the drive's
  evidence: `problem_class` (the order's `failure_class`),
  `applicability_predicate` (`applicability_predicate/1`: the order's
  failure class, repository, consequence class and authority ceiling, and
  no declared capability), `admitted_capability` / `provider_class` (what
  the drive executed), `required_evidence` / `falsifiers` (the order's
  evidence and falsifier IRIs plus the revert falsifier),
  `successful_verification`, `consequence_bounds` (`consequence_bounds/1`)
  and `source_episode`. The receipted record itself is manufactured by
  ggen_igniter's `GgenIgniter.SemanticJira.machine_experience/1` (standing
  CANDIDATE, authority NONE) and rendered as an `sj:MachineExperience` node
  that the pack's closed `sj:MachineExperienceShape` judges; the ARD section
  15 fields ride on a separate `xme:AdmittedExperience` node, because that
  shape is closed over the ggen_igniter fields.

  Vocabulary: `sj:` = `#{"https://ggen-igniter.dev/ontology/semantic-jira#"}`,
  `v23:` = `#{"https://ggen-igniter.dev/sjira/v26.9.23#"}`, `xme:` =
  `#{"https://xaas.dev/ontology/machine-experience#"}` (this lane's properties
  for the ARD section 15 fields and the order's failure class; not in the
  semantic-jira-pack ontology -- HANDWRITTEN.md).
  """

  @sj "https://ggen-igniter.dev/ontology/semantic-jira#"
  @v23 "https://ggen-igniter.dev/sjira/v26.9.23#"
  @xme "https://xaas.dev/ontology/machine-experience#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @rdfs_label "http://www.w3.org/2000/01/rdf-schema#label"

  @capability ~r/\A[a-z0-9][a-z0-9_.-]*:[a-z0-9][a-z0-9_.:-]*\z/
  @digest ~r/\Asha256:[0-9a-f]{64}\z/

  # order row key -> RDF property of the order rendering (`order_graph/1`)
  @order_properties [
    {"failure_class", @xme <> "failureClass"},
    {"repository", @sj <> "repository"},
    {"subject", @sj <> "subject"},
    {"base_sha", @sj <> "baseSha"},
    {"consequence_class", @sj <> "consequenceClass"},
    {"authority_ceiling", @sj <> "authorityCeiling"},
    {"evidence_ceiling", @sj <> "evidenceCeiling"},
    {"requires_capability", @sj <> "requiresCapability"},
    {"path_scope", @sj <> "pathScope"}
  ]

  # the routing-relevant fields a generalized predicate binds
  @predicate_fields [
    {"failure_class", "xme:failureClass"},
    {"repository", "sj:repository"},
    {"consequence_class", "sj:consequenceClass"},
    {"authority_ceiling", "sj:authorityCeiling"}
  ]

  # GgenIgniter.SemanticJira.machine_experience/1 key -> sj: property of the
  # closed sj:MachineExperienceShape (ggen_igniter's own goal-checkpoint test
  # uses exactly this map). "kind" is the rdf:type.
  @experience_fields [
    {"subject", "subject"},
    {"work_order_digest", "workOrderDigest"},
    {"execution_receipt_hash", "executionReceiptHash"},
    {"observation_refs", "observationRef"},
    {"verification_digest", "verificationDigest"},
    {"resulting_state_digest", "resultingStateDigest"},
    {"replay_identity", "replayIdentity"},
    {"standing", "standing"},
    {"authority", "authorityClaim"},
    {"experience_digest", "experienceDigest"}
  ]

  # ARD section 15 field -> xme: property on the admission node
  @admission_fields [
    {"problem_class", "problemClass"},
    {"applicability_predicate", "applicabilityPredicate"},
    {"admitted_capability", "admittedCapability"},
    {"provider_class", "providerClass"},
    {"required_evidence", "requiredEvidence"},
    {"falsifiers", "falsifier"},
    {"successful_verification", "successfulVerification"},
    {"consequence_bounds", "consequenceBounds"},
    {"source_episode", "sourceEpisode"},
    {"source_order", "sourceOrder"},
    {"source_exploration", "sourceExploration"},
    {"admission", "admission"},
    {"admission_digest", "admissionDigest"}
  ]

  @ard_fields ~w(problem_class applicability_predicate admitted_capability provider_class
                 required_evidence falsifiers successful_verification consequence_bounds
                 source_episode)

  @doc "Namespace IRIs: `%{sj:, v23:, xme:}`."
  @spec namespaces() :: %{String.t() => String.t()}
  def namespaces, do: %{"sj" => @sj, "v23" => @v23, "xme" => @xme}

  @doc "The ARD section 15 field names, in ARD order."
  @spec ard_fields() :: [String.t()]
  def ard_fields, do: @ard_fields

  # ---------------------------------------------------------------------------
  # the order's RDF rendering
  # ---------------------------------------------------------------------------

  @doc """
  The IRI of `row` in its RDF rendering: `v23:order-<16 hex>` of the sha256
  of its `replay_identity` (else its `identity`).
  """
  @spec order_iri(map()) :: String.t()
  def order_iri(row), do: @v23 <> "order-" <> hex16(row["replay_identity"] || row["identity"])

  @doc """
  The work-order row as RDF: `a sj:WorkOrder` plus one triple per present
  field of the order-property map (`xme:failureClass`, `sj:repository`,
  `sj:subject`, `sj:baseSha`, `sj:consequenceClass`, `sj:authorityCeiling`,
  `sj:evidenceCeiling`, `sj:requiresCapability`, `sj:pathScope`*). Blank and
  absent fields render no triple.
  """
  @spec order_graph(map()) :: RDF.Graph.t()
  def order_graph(row), do: row |> order_triples() |> triples_graph()

  @doc "The order rendering as Turtle (`to_turtle/2` conventions: sorted, prefixed)."
  @spec order_turtle(map()) :: String.t()
  def order_turtle(row), do: row |> order_triples() |> render_turtle()

  defp order_triples(row) do
    iri = order_iri(row)

    fields =
      Enum.flat_map(@order_properties, fn {key, property} ->
        row
        |> Map.get(key)
        |> List.wrap()
        |> Enum.filter(&nonblank?/1)
        |> Enum.map(&{iri, property, {:literal, &1}})
      end)

    [{iri, @rdf_type, {:iri, @sj <> "WorkOrder"}} | fields]
  end

  # ---------------------------------------------------------------------------
  # generalization: applicability predicate + consequence bounds
  # ---------------------------------------------------------------------------

  @doc """
  The applicability predicate generalized from a source order: a SPARQL
  SELECT of `?order` binding the order's failure class, repository,
  consequence class and authority ceiling, and requiring that the order
  declares no capability. `{:refused, typed}` when the order has no
  `failure_class` (`problem_class_absent`: nothing to generalize over).
  """
  @spec applicability_predicate(map()) :: {:ok, String.t()} | {:refused, map()}
  def applicability_predicate(row) do
    if nonblank?(row["failure_class"]) do
      bindings =
        @predicate_fields
        |> Enum.filter(fn {key, _} -> nonblank?(row[key]) end)
        |> Enum.map(fn {key, property} ->
          "    #{property} #{turtle_literal(row[key])}"
        end)

      {:ok,
       """
       PREFIX sj: <#{@sj}>
       PREFIX xme: <#{@xme}>
       SELECT ?order WHERE {
         ?order a sj:WorkOrder ;
       #{Enum.join(bindings, " ;\n")} .
         OPTIONAL { ?order sj:requiresCapability ?declared . }
         FILTER(!BOUND(?declared))
       }
       """}
    else
      {:refused,
       typed("REFUSED(problem_class_absent)", "problem_class_absent", "mu_on_O", "generalize", %{
         "order" => row["identity"]
       })}
    end
  end

  @doc """
  True iff the SPARQL `predicate` selects `row`'s IRI over `order_graph/1`.
  A predicate SPARQL.ex cannot parse or evaluate is false (never applicable).
  """
  @spec applies?(String.t(), map()) :: boolean()
  def applies?(predicate, row) when is_binary(predicate) do
    iri = RDF.iri(order_iri(row))

    case SPARQL.execute_query(order_graph(row), predicate) do
      %SPARQL.Query.Result{results: results} -> Enum.any?(results, &(&1["order"] == iri))
      _other -> false
    end
  rescue
    _error -> false
  end

  def applies?(_predicate, _row), do: false

  @doc """
  The consequence bounds of a source order: its authority ceiling,
  consequence class, path scope (sorted) and exclusions (sorted).
  """
  @spec consequence_bounds(map()) :: map()
  def consequence_bounds(row) do
    %{
      "authority_ceiling" => row["authority_ceiling"],
      "consequence_class" => row["consequence_class"],
      "path_scope" => row |> Map.get("path_scope", []) |> List.wrap() |> Enum.sort(),
      "exclusions" => row |> Map.get("exclusions", []) |> List.wrap() |> Enum.sort()
    }
  end

  @doc """
  True iff `row` stays within `bounds`: the same authority ceiling and
  consequence class, a non-empty path scope contained in the bounds' path
  scope, and every bounded exclusion still present on the order.
  """
  @spec within_bounds?(map(), map()) :: boolean()
  def within_bounds?(%{} = bounds, row) do
    scope = row |> Map.get("path_scope", []) |> List.wrap()
    exclusions = row |> Map.get("exclusions", []) |> List.wrap()

    row["authority_ceiling"] == bounds["authority_ceiling"] and
      row["consequence_class"] == bounds["consequence_class"] and
      scope != [] and
      Enum.all?(scope, &(&1 in List.wrap(bounds["path_scope"]))) and
      Enum.all?(List.wrap(bounds["exclusions"]), &(&1 in exclusions))
  end

  def within_bounds?(_bounds, _row), do: false

  # ---------------------------------------------------------------------------
  # the experience store
  # ---------------------------------------------------------------------------

  @doc """
  Reads Turtle files into one RDF graph (`{:ok, graph}`; no paths = the
  empty graph). An unreadable or unparseable file is refused
  (`experience_graph_unreadable`).
  """
  @spec load([String.t()]) :: {:ok, RDF.Graph.t()} | {:refused, map()}
  def load(paths) do
    Enum.reduce_while(paths, {:ok, RDF.Graph.new()}, fn path, {:ok, acc} ->
      with {:ok, bytes} <- File.read(path),
           {:ok, graph} <- RDF.Turtle.read_string(bytes) do
        {:cont, {:ok, RDF.Graph.add(acc, graph)}}
      else
        error ->
          {:halt,
           {:refused,
            typed(
              "REFUSED(experience_graph_unreadable)",
              "experience_graph_unreadable",
              "mu_on_O",
              "route",
              %{"path" => path, "error" => inspect(error)}
            )}}
      end
    end)
  end

  @doc """
  The ADMITTED experiences of `graph`, sorted by experience IRI: one map per
  `xme:AdmittedExperience` node with `xme:admission "ADMITTED"` whose
  `xme:experience` names a `sj:MachineExperience` node present in the graph
  with an `sj:experienceDigest`. Keys: `"machine_experience"`,
  `"admission"`, `"experience_digest"`, the ARD section 15 fields, and
  `"admission_digest"`. Incomplete admissions are left out.
  """
  @spec experiences(RDF.Graph.t()) :: [map()]
  def experiences(%RDF.Graph{} = graph) do
    graph
    |> subjects_of_type(@xme <> "AdmittedExperience")
    |> Enum.flat_map(fn admission -> admitted(graph, admission) end)
    |> Enum.sort_by(& &1["machine_experience"])
  end

  defp admitted(graph, admission) do
    with ["ADMITTED"] <- values(graph, admission, @xme <> "admission"),
         [%RDF.IRI{} = me] <- objects(graph, admission, @xme <> "experience"),
         true <- typed?(graph, me, @sj <> "MachineExperience"),
         [digest] <- values(graph, me, @sj <> "experienceDigest"),
         [capability] <- values(graph, admission, @xme <> "admittedCapability"),
         true <- Regex.match?(@capability, capability),
         [predicate] <- values(graph, admission, @xme <> "applicabilityPredicate"),
         [bounds_json] <- values(graph, admission, @xme <> "consequenceBounds"),
         {:ok, %{} = bounds} <- Jason.decode(bounds_json) do
      [
        %{
          "machine_experience" => to_string(me),
          "admission" => to_string(admission),
          "experience_digest" => digest,
          "problem_class" => single(graph, admission, "problemClass"),
          "applicability_predicate" => predicate,
          "admitted_capability" => capability,
          "provider_class" => single(graph, admission, "providerClass"),
          "required_evidence" => values(graph, admission, @xme <> "requiredEvidence"),
          "falsifiers" => values(graph, admission, @xme <> "falsifier"),
          "successful_verification" => single(graph, admission, "successfulVerification"),
          "consequence_bounds" => bounds,
          "source_episode" => single(graph, admission, "sourceEpisode"),
          "admission_digest" => single(graph, admission, "admissionDigest")
        }
      ]
    else
      _ -> []
    end
  end

  # ---------------------------------------------------------------------------
  # the router
  # ---------------------------------------------------------------------------

  @doc """
  Routes one work-order row (see the moduledoc). `{:known, route}` with
  `"source"` `"requires_capability"` or `"machine_experience"` (then
  `"machine_experience"` is the experience IRI and `"capability"` its
  `xme:admittedCapability`), or `{:unknown, typed}` with standing
  `"UNKNOWN"` and reason `no_capability_no_experience` /
  `ambiguous_experience`. `{:refused, typed}` for a declared capability
  outside the canonical `provider:id` pattern.
  """
  @spec route(map(), RDF.Graph.t() | nil) ::
          {:known, map()} | {:unknown, map()} | {:refused, map()}
  def route(row, graph \\ nil)

  def route(%{"requires_capability" => declared} = row, _graph) when is_binary(declared) do
    if Regex.match?(@capability, declared) do
      {:known,
       %{"source" => "requires_capability", "capability" => declared, "order" => row["identity"]}}
    else
      {:refused,
       typed("REFUSED(invalid_capability)", "invalid_capability", "mu_on_O", "route", %{
         "capability" => declared
       })}
    end
  end

  def route(row, graph) do
    considered = if graph, do: experiences(graph), else: []

    applicable =
      Enum.filter(considered, fn experience ->
        applies?(experience["applicability_predicate"], row) and
          within_bounds?(experience["consequence_bounds"], row)
      end)

    detail = %{
      "order" => row["identity"],
      "failure_class" => row["failure_class"],
      "experiences_considered" => Enum.map(considered, & &1["machine_experience"]),
      "experiences_applicable" => Enum.map(applicable, & &1["machine_experience"])
    }

    case applicable |> Enum.map(& &1["admitted_capability"]) |> Enum.uniq() do
      [] ->
        {:unknown, unknown("no_capability_no_experience", detail)}

      [capability] ->
        experience = hd(applicable)

        {:known,
         %{
           "source" => "machine_experience",
           "capability" => capability,
           "order" => row["identity"],
           "machine_experience" => experience["machine_experience"],
           "admission" => experience["admission"],
           "experience_digest" => experience["experience_digest"],
           "admission_digest" => experience["admission_digest"],
           "problem_class" => experience["problem_class"],
           "provider_class" => experience["provider_class"],
           "predicate_sha256" => sha256(experience["applicability_predicate"]),
           "experiences_considered" => detail["experiences_considered"],
           "experiences_applicable" => detail["experiences_applicable"]
         }}

      capabilities ->
        {:unknown,
         unknown("ambiguous_experience", Map.put(detail, "capabilities", Enum.sort(capabilities)))}
    end
  end

  defp unknown(reason, detail),
    do: %{"standing" => "UNKNOWN", "reason" => reason, "hop" => "route", "detail" => detail}

  # ---------------------------------------------------------------------------
  # manufacture
  # ---------------------------------------------------------------------------

  @doc """
  The ARD section 15 fields derived from the source order `row` and the
  drive evidence (`drive` = the drive summary, `verification` = its
  `verification.json`, `receipt` = its sealed `receipt.json`), with
  `source_episode` and `source_exploration` (the exploration artifact
  digest) from `source`. `{:refused, typed}` when the order has no
  failure class.
  """
  @spec generalize(map(), map(), map()) :: {:ok, map()} | {:refused, map()}
  def generalize(row, evidence, source) do
    drive = evidence["drive"]
    verification = evidence["verification"]
    receipt = evidence["receipt"]

    with {:ok, predicate} <- applicability_predicate(row) do
      {:ok,
       %{
         "problem_class" => row["failure_class"],
         "applicability_predicate" => predicate,
         "admitted_capability" => get_in(drive, ["provider", "capability"]),
         "provider_class" => get_in(drive, ["provider", "provider"]),
         "required_evidence" =>
           Enum.sort(List.wrap(row["required_evidence"]) ++ List.wrap(row["evidence_horizon"])),
         "falsifiers" =>
           Enum.sort(
             List.wrap(row["falsifiers"]) ++
               [
                 "revert falsifier: the #{get_in(verification, ["independent", "suite"])} court must fail with the provider's commit reverted"
               ]
           ),
         "successful_verification" =>
           canonical_json(%{
             "suite" => get_in(verification, ["independent", "suite"]),
             "head" => verification["head"],
             "independent" => get_in(verification, ["independent", "status"]),
             "revert_falsifier" => get_in(verification, ["revert_falsifier", "verdict"]),
             "receipt_digest" => receipt["receipt_digest"],
             "standing" => drive["standing"]
           }),
         "consequence_bounds" => canonical_json(consequence_bounds(row)),
         "source_episode" => source["episode"],
         "source_order" => source["order"],
         "source_exploration" => source["exploration_digest"]
       }}
    end
  end

  @doc """
  The input map of `GgenIgniter.SemanticJira.machine_experience/1` for a
  drive that reached ALIVE: subject, the sJira hop's `work_order_digest`,
  the sealed receipt digest as the executed receipt, `observation_refs`
  (repository-relative paths of the drive's evidence), the verification
  (passed iff the independent court passed AND the revert falsifier
  killed), the resulting state and the order's replay identity.
  """
  @spec experience_attrs(map(), map(), [String.t()]) :: map()
  def experience_attrs(row, evidence, observation_refs) do
    drive = evidence["drive"]
    verification = evidence["verification"]
    receipt = evidence["receipt"]
    hops = evidence["hops"]
    sjira = Enum.find(hops["hops"] || [], &(&1["hop"] == "sjira")) || %{}

    %{
      "subject" => row["subject"],
      "work_order_digest" => get_in(sjira, ["request", "graph_digest"]),
      "execution_receipt" => %{
        "executed" => receipt["outcome"] == "alive",
        "receipt_hash" => receipt["receipt_digest"]
      },
      "observation_refs" => observation_refs,
      "verification" => %{
        "passed" =>
          get_in(verification, ["independent", "status"]) == "pass" and
            get_in(verification, ["revert_falsifier", "verdict"]) == "killed",
        "suite" => get_in(verification, ["independent", "suite"]),
        "head" => verification["head"],
        "independent" => get_in(verification, ["independent", "status"]),
        "revert_falsifier" => get_in(verification, ["revert_falsifier", "verdict"])
      },
      "resulting_state" => %{
        "head" => drive["subject"]["head"],
        "standing" => drive["standing"],
        "frontier" => drive["frontier"],
        "ledger_tail" => get_in(drive, ["transition", "event_digest"])
      },
      "replay_identity" => row["replay_identity"]
    }
  end

  @doc """
  The IRI of a manufactured experience: `v23:ME-<first 16 hex of its
  experience_digest>`.
  """
  @spec iri(map()) :: String.t()
  def iri(%{"experience_digest" => "sha256:" <> hex}),
    do: @v23 <> "ME-" <> binary_part(hex, 0, 16)

  @doc """
  Admission of a manufactured experience (the gate; it can refuse): the
  ggen_igniter record must be exactly the shape's field set with standing
  CANDIDATE, authority NONE and sha256-shaped digests; every ARD section 15
  field must be non-blank; the admitted capability must be canonical; the
  applicability predicate must select its own source order and the bounds
  must contain it; and `evidence` must show an ALIVE drive whose independent
  court passed and whose revert falsifier killed. `{:ok, admission}` (the
  fields plus `"admission" => "ADMITTED"` and `"admission_digest"`) or
  `{:refused, typed}` naming the first failed condition.
  """
  @spec admit(map(), map(), map(), map()) :: {:ok, map()} | {:refused, map()}
  def admit(experience, fields, row, evidence) do
    keys = experience |> Map.keys() |> Enum.sort()
    expected = ["kind" | Enum.map(@experience_fields, &elem(&1, 0))] |> Enum.sort()
    drive = evidence["drive"] || %{}
    verification = evidence["verification"] || %{}

    checks = [
      {keys == expected, "experience_fields_unmapped", %{"keys" => keys}},
      {experience["kind"] == "MachineExperience" and experience["standing"] == "CANDIDATE" and
         experience["authority"] == "NONE", "experience_not_candidate",
       Map.take(experience, ~w(kind standing authority))},
      {Enum.all?(
         ~w(work_order_digest execution_receipt_hash verification_digest resulting_state_digest experience_digest),
         &Regex.match?(@digest, experience[&1] || "")
       ), "experience_digest_malformed", Map.take(experience, ~w(experience_digest))},
      {Enum.all?(@ard_fields, &nonblank_field?(fields[&1])), "ard_field_missing",
       %{"missing" => Enum.reject(@ard_fields, &nonblank_field?(fields[&1]))}},
      {Regex.match?(@capability, fields["admitted_capability"] || ""), "invalid_capability",
       %{"capability" => fields["admitted_capability"]}},
      {applies?(fields["applicability_predicate"], row), "predicate_excludes_source",
       %{"order" => row["identity"]}},
      {within_bounds?(decode(fields["consequence_bounds"]), row), "bounds_exclude_source",
       %{"order" => row["identity"]}},
      {drive["standing"] == "ALIVE", "source_not_alive", %{"standing" => drive["standing"]}},
      {get_in(verification, ["independent", "status"]) == "pass" and
         get_in(verification, ["revert_falsifier", "verdict"]) == "killed", "source_unverified",
       %{
         "independent" => get_in(verification, ["independent", "status"]),
         "revert_falsifier" => get_in(verification, ["revert_falsifier", "verdict"])
       }}
    ]

    case Enum.find(checks, fn {ok, _reason, _detail} -> not ok end) do
      nil ->
        admission = Map.put(fields, "admission", "ADMITTED")

        digest =
          sha256(
            canonical_json(
              Map.put(admission, "experience_digest", experience["experience_digest"])
            )
          )

        {:ok, Map.put(admission, "admission_digest", digest)}

      {_ok, reason, detail} ->
        {:refused, typed("REFUSED(#{reason})", reason, "admission_vacuous", "admit", detail)}
    end
  end

  @doc """
  The admitted experience as Turtle: the `sj:MachineExperience` node
  (exactly the ggen_igniter record's fields, `rdfs:label`) and the
  `xme:AdmittedExperience` node carrying the ARD section 15 fields, the
  admission and its digest, linked by `xme:experience`. Triples are sorted;
  the same inputs render the same bytes.
  """
  @spec to_turtle(map(), map()) :: String.t()
  def to_turtle(experience, admission) do
    me = iri(experience)
    node = me <> "-admission"

    me_triples =
      [
        {me, @rdf_type, {:iri, @sj <> "MachineExperience"}},
        {me, @rdfs_label,
         {:literal,
          "MachineExperience #{admission["problem_class"]} -> #{admission["admitted_capability"]} (episode #{admission["source_episode"]})"}}
      ] ++
        Enum.flat_map(@experience_fields, fn {key, property} ->
          experience
          |> Map.fetch!(key)
          |> List.wrap()
          |> Enum.map(&{me, @sj <> property, {:literal, &1}})
        end)

    admission_triples =
      [
        {node, @rdf_type, {:iri, @xme <> "AdmittedExperience"}},
        {node, @rdfs_label,
         {:literal,
          "Admission of #{admission["problem_class"]} MachineExperience (ARD section 15)"}},
        {node, @xme <> "experience", {:iri, me}}
      ] ++
        Enum.flat_map(@admission_fields, fn {key, property} ->
          admission
          |> Map.get(key)
          |> List.wrap()
          |> Enum.filter(&nonblank?/1)
          |> Enum.map(&{node, @xme <> property, {:literal, &1}})
        end)

    render_turtle(me_triples ++ admission_triples)
  end

  # ---------------------------------------------------------------------------
  # helpers
  # ---------------------------------------------------------------------------

  @doc "`\"sha256:\" <> hex` of `bytes`."
  @spec sha256(iodata()) :: String.t()
  def sha256(bytes),
    do: "sha256:" <> (:crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower))

  @doc "Canonical JSON: sorted keys, compact, UTF-8 unescaped."
  @spec canonical_json(term()) :: String.t()
  def canonical_json(value), do: value |> canonical() |> Jason.encode!()

  defp canonical(%{} = map),
    do:
      Jason.OrderedObject.new(
        map
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.map(fn {k, v} -> {k, canonical(v)} end)
      )

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  defp canonical(value), do: value

  defp decode(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, value} -> value
      _ -> nil
    end
  end

  defp decode(_), do: nil

  defp hex16(value),
    do:
      :crypto.hash(:sha256, to_string(value)) |> Base.encode16(case: :lower) |> binary_part(0, 16)

  defp nonblank?(value), do: is_binary(value) and String.trim(value) != ""

  defp nonblank_field?(value) when is_list(value),
    do: value != [] and Enum.all?(value, &nonblank?/1)

  defp nonblank_field?(value), do: nonblank?(value)

  defp typed(standing, reason, broken_term, hop, detail) do
    %{
      "standing" => standing,
      "reason" => reason,
      "broken_term" => broken_term,
      "hop" => hop,
      "detail" => detail
    }
  end

  # -- RDF access ---------------------------------------------------------------

  defp subjects_of_type(graph, class) do
    type = RDF.iri(@rdf_type)
    class = RDF.iri(class)

    graph
    |> RDF.Graph.triples()
    |> Enum.filter(fn {_s, p, o} -> p == type and o == class end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.uniq()
  end

  defp typed?(graph, subject, class) do
    RDF.Graph.include?(graph, {subject, RDF.iri(@rdf_type), RDF.iri(class)})
  end

  defp objects(graph, subject, property) do
    case RDF.Graph.description(graph, subject) do
      nil -> []
      description -> description |> RDF.Description.get(RDF.iri(property), []) |> Enum.sort()
    end
  end

  defp values(graph, subject, property) do
    graph
    |> objects(subject, property)
    |> Enum.flat_map(fn
      %RDF.Literal{} = literal -> [RDF.Literal.lexical(literal)]
      _other -> []
    end)
    |> Enum.sort()
  end

  defp single(graph, subject, name) do
    case values(graph, subject, @xme <> name) do
      [value] -> value
      _ -> nil
    end
  end

  # -- Turtle rendering -----------------------------------------------------------

  defp triples_graph(triples) do
    RDF.Graph.new(
      Enum.map(triples, fn
        {s, p, {:iri, o}} -> {RDF.iri(s), RDF.iri(p), RDF.iri(o)}
        {s, p, {:literal, o}} -> {RDF.iri(s), RDF.iri(p), RDF.literal(o)}
      end)
    )
  end

  defp render_turtle(triples) do
    prefixes = [
      {"rdf", "http://www.w3.org/1999/02/22-rdf-syntax-ns#"},
      {"rdfs", "http://www.w3.org/2000/01/rdf-schema#"},
      {"sj", @sj},
      {"v23", @v23},
      {"xme", @xme}
    ]

    header = Enum.map(prefixes, fn {p, ns} -> "@prefix #{p}: <#{ns}> .\n" end)

    body =
      triples
      |> Enum.uniq()
      |> Enum.group_by(&elem(&1, 0))
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {subject, subject_triples} ->
        lines =
          subject_triples
          |> Enum.map(fn {_s, p, o} -> {term(p, prefixes), object_term(o, prefixes)} end)
          |> Enum.sort()
          |> Enum.map(fn {p, o} -> "    #{p} #{o}" end)

        "#{term(subject, prefixes)}\n" <> Enum.join(lines, " ;\n") <> " .\n"
      end)

    IO.iodata_to_binary([header, "\n", Enum.intersperse(body, "\n")])
  end

  defp object_term({:iri, iri}, prefixes), do: term(iri, prefixes)
  defp object_term({:literal, value}, _prefixes), do: turtle_literal(value)

  defp term(iri, prefixes) do
    Enum.find_value(prefixes, "<#{iri}>", fn {prefix, ns} ->
      local = String.replace_prefix(iri, ns, "")

      if String.starts_with?(iri, ns) and Regex.match?(~r/\A[A-Za-z][A-Za-z0-9_-]*\z/, local),
        do: "#{prefix}:#{local}"
    end)
  end

  defp turtle_literal(value) do
    escaped =
      value
      |> to_string()
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
      |> String.replace("\n", "\\n")
      |> String.replace("\r", "\\r")
      |> String.replace("\t", "\\t")

    "\"" <> escaped <> "\""
  end
end
