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
       `xme:AdmittedExperience` node with `xme:admission "ADMITTED"` that
       VERIFIES (`admissions/1`) -- its `xme:experience` names a present
       `sj:MachineExperience` node whose record passes admission's record
       checks (the exact field set, CANDIDATE/NONE, sha256 digests, set-shaped
       observation refs) and whose `sj:experienceDigest` recomputes
       (`experience_digest/1`, ggen_igniter's `SemanticJira.digest/1`); its
       ARD section 15 fields are complete, its capability canonical, its
       bounds decodable; its `xme:admissionDigest` recomputes
       (`admission_digest/2` over the admission fields AND the whole
       experience record); and the two nodes carry exactly the triples
       `to_turtle/2` renders from what was read (closed). A verified
       admission applies when its `xme:applicabilityPredicate` (a SPARQL
       SELECT over the order's RDF rendering, `order_graph/1`) selects the
       order and its `xme:consequenceBounds` contain the order's authority
       ceiling, consequence class and path scope. The route names the
       experience by IRI and takes the capability from the graph's
       `xme:admittedCapability` of a verified admission -- never from a
       literal in code or in the order, and never from an admission edited
       after `admit/4`;
    3. otherwise UNKNOWN (`no_capability_no_experience`), or UNKNOWN
       (`ambiguous_experience`) when applicable experiences name different
       capabilities.

  The router fails closed: an ADMITTED node that does not verify refuses the
  route (`REFUSED(experience_admission_invalid)`, naming the node and the
  failed check), and so does a verified admission whose predicate cannot be
  evaluated (`REFUSED(experience_predicate_unevaluable)`). Neither is ever
  read as "no experience": it might apply, and beside another experience
  make the route ambiguous. Removing the whole admitted experience (both
  nodes), or its admission node, turns a KNOWN route UNKNOWN; removing only
  the `sj:MachineExperience` node under an ADMITTED admission refuses it.

  Digest recomputation detects any edit made without recomputing the
  digests; it is content addressing, not authority (a writer who recomputes
  them forges a self-consistent node -- authority stays with BRCE, leases
  and receipts).

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

  alias Xaas.Ultracode.MachineExperience.Exploration

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

  # admission fields that are sets (0..n literals); every other one is 0..1
  @admission_list_fields ~w(required_evidence falsifiers)

  # the admission digest's input schema (v2: the admission fields AND the
  # whole experience record, both in graph normal form)
  @admission_schema "xaas/machine-experience-admission/v2"

  # the record fields GgenIgniter.SemanticJira.digest/1 elides
  # (drop_digest_fields/1 in ggen_igniter lib/ggen_igniter/semantic_jira.ex)
  @ggen_elided ~w(definition_digest work_order_digest transition_digest evidence_digest
                  receipt_digest experience_digest repair_digest finding_digest
                  composition_digest)

  @record_digest_fields ~w(work_order_digest execution_receipt_hash verification_digest
                           resulting_state_digest experience_digest)

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
  Evaluates the SPARQL `predicate` over `order_graph/1` of `row`:
  `{:ok, true}` iff it selects `row`'s IRI as `?order`, `{:ok, false}` when
  it evaluates and does not, and `{:error, detail}` when it cannot be judged
  -- not a string, SPARQL.ex refuses to parse or evaluate it (its error, or
  what it raised), the result is not a SELECT result, or the SELECT does
  not project `?order`. An unevaluable predicate is never read as "does not
  apply": callers turn `{:error, detail}` into their own typed refusal
  (`route/2`: `REFUSED(experience_predicate_unevaluable)`; `admit/4`:
  `REFUSED(predicate_unevaluable)`).
  """
  @spec applicability(term(), map()) :: {:ok, boolean()} | {:error, map()}
  def applicability(predicate, row) when is_binary(predicate) do
    iri = RDF.iri(order_iri(row))

    case evaluate(order_graph(row), predicate) do
      {:ok, %SPARQL.Query.Result{variables: variables, results: results}} ->
        if "order" in List.wrap(variables),
          do: {:ok, Enum.any?(results, &(&1["order"] == iri))},
          else: unevaluable("select_without_order", %{"variables" => variables})

      {:ok, other} ->
        unevaluable("not_a_select_result", %{"result" => inspect(other, limit: 5)})

      {:error, reason} ->
        unevaluable("sparql_error", %{"error" => reason})
    end
  end

  def applicability(predicate, _row),
    do: unevaluable("predicate_not_a_string", %{"predicate" => inspect(predicate, limit: 5)})

  # SPARQL.ex returns `{:error, message}` for what its scanner/parser
  # refuses and may raise on what it cannot evaluate; both are reported,
  # never swallowed.
  defp evaluate(graph, predicate) do
    case SPARQL.execute_query(graph, predicate) do
      {:error, reason} -> {:error, to_string_safe(reason)}
      result -> {:ok, result}
    end
  rescue
    error -> {:error, Exception.format(:error, error, __STACKTRACE__) |> String.slice(0, 600)}
  end

  defp unevaluable(kind, detail), do: {:error, Map.put(detail, "kind", kind)}

  defp to_string_safe(reason) when is_binary(reason), do: reason
  defp to_string_safe(reason), do: inspect(reason, limit: 20)

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
  The VERIFIED ADMITTED experiences of `graph`, sorted by experience IRI
  (`admissions(graph)["admitted"]`). Keys: `"machine_experience"`,
  `"admission"`, `"experience_digest"`, the ARD section 15 fields
  (`"consequence_bounds"` decoded), `"source_order"`,
  `"source_exploration"` and `"admission_digest"`.
  """
  @spec experiences(RDF.Graph.t()) :: [map()]
  def experiences(%RDF.Graph{} = graph), do: admissions(graph)["admitted"]

  @doc """
  Judges every `xme:AdmittedExperience` node of `graph` (sorted by IRI) and
  returns `%{"admitted" => [...], "invalid" => [...], "not_admitted" =>
  [...], "without_admission" => [...]}`:

    * `"not_admitted"` -- the node's `xme:admission` does not include
      `"ADMITTED"` (`%{"admission", "admission_values"}`): never routable,
      never ambiguous;
    * `"admitted"` -- `xme:admission` is `"ADMITTED"` and the node verifies
      (the experience map of `experiences/1`);
    * `"invalid"` -- `xme:admission` includes `"ADMITTED"` but the node does
      not verify: `%{"admission", "machine_experience", "reason", ...}` with
      the first failed check, in this order: `admission_not_single` (the
      admission is not exactly `"ADMITTED"`), `experience_link_not_single`,
      `experience_absent`, `experience_field_not_single`, the record checks
      of `admit/4` (`experience_fields_unmapped`, `experience_not_candidate`,
      `experience_digest_malformed`, `experience_not_graph_representable`,
      `experience_digest_mismatch`), `admission_field_not_single`,
      `ard_field_missing`, `invalid_capability`,
      `consequence_bounds_undecodable`, `admission_digest_mismatch`,
      `admission_not_closed` (the two nodes' triples are not exactly those
      `to_turtle/2` renders from what was read: an extra or retyped triple);
    * `"without_admission"` -- `sj:MachineExperience` IRIs no
      `xme:AdmittedExperience` node links (CANDIDATE records, never routes).

  Nothing is dropped silently: every node lands in exactly one list.
  """
  @spec admissions(RDF.Graph.t()) :: %{String.t() => [map() | String.t()]}
  def admissions(%RDF.Graph{} = graph) do
    nodes = graph |> subjects_of_type(@xme <> "AdmittedExperience") |> Enum.sort_by(&to_string/1)
    linked = nodes |> Enum.flat_map(&objects(graph, &1, @xme <> "experience")) |> MapSet.new()

    judged =
      Enum.reduce(nodes, %{"admitted" => [], "invalid" => [], "not_admitted" => []}, fn node,
                                                                                        acc ->
        {bucket, value} = judge(graph, node)
        Map.update!(acc, bucket, &(&1 ++ [value]))
      end)

    without =
      graph
      |> subjects_of_type(@sj <> "MachineExperience")
      |> Enum.reject(&MapSet.member?(linked, &1))
      |> Enum.map(&to_string/1)
      |> Enum.sort()

    judged
    |> Map.update!("admitted", &Enum.sort_by(&1, fn e -> e["machine_experience"] end))
    |> Map.put("without_admission", without)
  end

  defp judge(graph, node) do
    admission_values = values(graph, node, @xme <> "admission")

    if "ADMITTED" in admission_values do
      case verify(graph, node, admission_values) do
        {:ok, experience} ->
          {"admitted", experience}

        {:refuse, reason, detail} ->
          {"invalid",
           detail
           |> Map.merge(%{"admission" => to_string(node), "reason" => reason})
           |> Map.put_new("machine_experience", nil)}
      end
    else
      {"not_admitted", %{"admission" => to_string(node), "admission_values" => admission_values}}
    end
  end

  # Re-admission from the graph: every check of admit/4 that the graph can
  # answer, plus both digests recomputed and the nodes closed. The lazy
  # `with` stops at the first failed check.
  defp verify(graph, node, admission_values) do
    with :ok <-
           check(admission_values == ["ADMITTED"], "admission_not_single", %{
             "admission_values" => admission_values
           }),
         {:ok, me} <- experience_link(graph, node),
         {:ok, record} <- read_record(graph, me),
         :ok <- first_refusal(record_checks(record)),
         {:ok, admission} <- read_admission(graph, node, me),
         :ok <- first_refusal(admission_checks(admission)),
         :ok <-
           check(
             admission["admission_digest"] == admission_digest(record, admission),
             "admission_digest_mismatch",
             %{
               "machine_experience" => to_string(me),
               "recorded" => admission["admission_digest"]
             }
           ),
         :ok <- closed(graph, node, me, record, admission) do
      {:ok,
       admission
       |> Map.take(@ard_fields ++ ~w(source_order source_exploration admission_digest))
       |> Map.merge(%{
         "machine_experience" => to_string(me),
         "admission" => to_string(node),
         "experience_digest" => record["experience_digest"],
         "consequence_bounds" => Jason.decode!(admission["consequence_bounds"])
       })}
    end
  end

  defp experience_link(graph, node) do
    case objects(graph, node, @xme <> "experience") do
      [%RDF.IRI{} = me] ->
        if typed?(graph, me, @sj <> "MachineExperience"),
          do: {:ok, me},
          else: {:refuse, "experience_absent", %{"machine_experience" => to_string(me)}}

      linked ->
        {:refuse, "experience_link_not_single", %{"linked" => Enum.map(linked, &to_string/1)}}
    end
  end

  # the sj:MachineExperience node as the ggen_igniter record it renders
  defp read_record(graph, me) do
    Enum.reduce_while(@experience_fields, {:ok, %{"kind" => "MachineExperience"}}, fn
      {"observation_refs" = key, property}, {:ok, acc} ->
        {:cont, {:ok, Map.put(acc, key, values(graph, me, @sj <> property))}}

      {key, property}, {:ok, acc} ->
        case values(graph, me, @sj <> property) do
          [value] ->
            {:cont, {:ok, Map.put(acc, key, value)}}

          found ->
            {:halt,
             {:refuse, "experience_field_not_single",
              %{"machine_experience" => to_string(me), "field" => key, "values" => found}}}
        end
    end)
  end

  # the xme:AdmittedExperience node as the admission map admit/4 returned
  defp read_admission(graph, node, me) do
    Enum.reduce_while(@admission_fields, {:ok, %{}}, fn {key, property}, {:ok, acc} ->
      found = values(graph, node, @xme <> property)

      cond do
        key in @admission_list_fields ->
          {:cont, {:ok, Map.put(acc, key, found)}}

        length(found) <= 1 ->
          {:cont, {:ok, Map.put(acc, key, List.first(found))}}

        true ->
          {:halt,
           {:refuse, "admission_field_not_single",
            %{"machine_experience" => to_string(me), "field" => key, "values" => found}}}
      end
    end)
  end

  # The two nodes carry exactly the triples to_turtle/2 renders from what
  # was read: nothing extra (an unknown property, a second rdf:type, a typed
  # literal where a plain one was rendered) and nothing under another IRI.
  defp closed(graph, node, me, record, admission) do
    rendered = record |> to_turtle(admission) |> RDF.Turtle.read_string!()

    present =
      [me, node]
      |> Enum.flat_map(fn subject ->
        case RDF.Graph.description(graph, subject) do
          nil -> []
          description -> RDF.Description.triples(description)
        end
      end)
      |> MapSet.new()

    expected = rendered |> RDF.Graph.triples() |> MapSet.new()
    extra = MapSet.difference(present, expected)
    missing = MapSet.difference(expected, present)

    check(MapSet.size(extra) == 0 and MapSet.size(missing) == 0, "admission_not_closed", %{
      "machine_experience" => to_string(me),
      "extra" => extra |> Enum.map(&inspect/1) |> Enum.sort() |> Enum.take(5),
      "missing" => missing |> Enum.map(&inspect/1) |> Enum.sort() |> Enum.take(5)
    })
  end

  # -- checks shared by admit/4 (at admission) and verify/3 (at routing) ------

  defp record_checks(record) do
    keys = record |> Map.keys() |> Enum.sort()
    expected = ["kind" | Enum.map(@experience_fields, &elem(&1, 0))] |> Enum.sort()

    [
      fn -> check(keys == expected, "experience_fields_unmapped", %{"keys" => keys}) end,
      fn ->
        check(
          record["kind"] == "MachineExperience" and record["standing"] == "CANDIDATE" and
            record["authority"] == "NONE",
          "experience_not_candidate",
          Map.take(record, ~w(kind standing authority))
        )
      end,
      fn ->
        check(
          Enum.all?(
            @record_digest_fields,
            &Regex.match?(@digest, to_string_or_empty(record[&1]))
          ),
          "experience_digest_malformed",
          Map.take(record, @record_digest_fields)
        )
      end,
      fn ->
        refs = record["observation_refs"]

        check(
          Enum.all?(Map.keys(record) -- ["observation_refs"], &nonblank?(record[&1])) and
            is_list(refs) and refs != [] and Enum.all?(refs, &nonblank?/1) and
            refs == refs |> Enum.uniq() |> Enum.sort(),
          "experience_not_graph_representable",
          %{"observation_refs" => refs}
        )
      end,
      fn ->
        computed = experience_digest(record)

        check(computed == record["experience_digest"], "experience_digest_mismatch", %{
          "recorded" => record["experience_digest"],
          "computed" => computed
        })
      end
    ]
  end

  defp admission_checks(admission) do
    malformed =
      Enum.reject(@ard_fields, fn field ->
        value = admission[field]

        if field in @admission_list_fields,
          do: is_list(value) and value != [] and Enum.all?(value, &nonblank?/1),
          else: nonblank?(value)
      end)

    [
      fn -> check(malformed == [], "ard_field_missing", %{"missing" => malformed}) end,
      fn ->
        check(
          Regex.match?(@capability, to_string_or_empty(admission["admitted_capability"])),
          "invalid_capability",
          %{"capability" => admission["admitted_capability"]}
        )
      end,
      fn ->
        check(
          is_map(decode(admission["consequence_bounds"])),
          "consequence_bounds_undecodable",
          %{
            "consequence_bounds" => admission["consequence_bounds"]
          }
        )
      end
    ]
  end

  defp first_refusal(checks) do
    Enum.find_value(checks, :ok, fn condition ->
      case condition.() do
        :ok -> nil
        refusal -> refusal
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # digests
  # ---------------------------------------------------------------------------

  @doc """
  The experience digest of a ggen_igniter experience record, exactly as
  `GgenIgniter.SemanticJira.digest/1` computes it (ggen_igniter
  lib/ggen_igniter/semantic_jira.ex): the top-level `*_digest` fields it
  elides (`work_order_digest`, `experience_digest`, ...) dropped, every map
  rendered as its key-sorted list of `[key, value]` pairs, `Jason.encode!/1`,
  `"sha256:" <> hex`. ggen_igniter is not a compile-time dependency of this
  application (xaas pins the hex release, which has no SemanticJira), so the
  formula is bound here and qualified against the real function: `admit/4`
  refuses a record whose digest does not recompute
  (`experience_digest_mismatch`), the end-to-end test compares it with
  records the real `machine_experience/1` manufactured, and the GC23-9 court
  has ggen_igniter's own `digest/1` recompute the committed record.
  """
  @spec experience_digest(map()) :: String.t()
  def experience_digest(%{} = record) do
    record
    |> Map.drop(@ggen_elided)
    |> ggen_canonical()
    |> Jason.encode!()
    |> sha256()
  end

  defp ggen_canonical(%{} = map) when not is_struct(map) do
    map
    |> Enum.map(fn {key, value} -> [to_string(key), ggen_canonical(value)] end)
    |> Enum.sort_by(&hd/1)
  end

  defp ggen_canonical(list) when is_list(list), do: Enum.map(list, &ggen_canonical/1)
  defp ggen_canonical(value) when is_boolean(value) or is_nil(value), do: value
  defp ggen_canonical(value) when is_atom(value), do: Atom.to_string(value)
  defp ggen_canonical(value), do: value

  @doc """
  The admission digest (#{@admission_schema}): sha256 of the canonical JSON
  of `%{"schema", "experience", "admission"}` -- the WHOLE experience record
  (every field the `sj:MachineExperience` node carries, including
  `work_order_digest`, which the experience digest elides) and the
  admission's fields and verdict without the digest itself, both in graph
  normal form (`admission_form/1`: set-valued fields de-duplicated and
  sorted, blank values nil), so the digest recomputed from the rendered
  graph equals the one `admit/4` recorded iff nothing was edited.
  """
  @spec admission_digest(map(), map()) :: String.t()
  def admission_digest(experience, admission) do
    sha256(
      canonical_json(%{
        "schema" => @admission_schema,
        "experience" => experience,
        "admission" => admission_form(admission)
      })
    )
  end

  @doc """
  The admission map in graph normal form: every `xme:` admission field but
  the digest (the ARD section 15 fields, `source_order`,
  `source_exploration`, `admission`); set-valued fields
  (`required_evidence`, `falsifiers`) as sorted unique lists of non-blank
  strings, every other field its non-blank value or nil.
  """
  @spec admission_form(map()) :: map()
  def admission_form(admission) do
    @admission_fields
    |> Enum.reject(fn {key, _} -> key == "admission_digest" end)
    |> Map.new(fn {key, _} ->
      value = admission[key]

      if key in @admission_list_fields,
        do:
          {key, value |> List.wrap() |> Enum.filter(&nonblank?/1) |> Enum.uniq() |> Enum.sort()},
        else: {key, if(nonblank?(value), do: value)}
    end)
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
  `ambiguous_experience`. `{:refused, typed}` (broken term `mu_on_O`) for a
  declared capability outside the canonical `provider:id` pattern;
  `REFUSED(experience_admission_invalid)` when any ADMITTED node of the
  graph does not verify (`admissions/1`; the detail lists every such node
  with its failed check) -- whether or not it would apply, since what an
  unverified admission says (its predicate, bounds and capability) cannot
  be trusted to decide that; and `REFUSED(experience_predicate_unevaluable)`
  when a verified admission's applicability predicate cannot be evaluated
  (`applicability/2`). The router fails closed rather than report "no
  experience" for an experience it could not judge (it might apply, and
  with another experience make the route ambiguous). The UNKNOWN detail
  also names the admissions that are not ADMITTED and the
  `sj:MachineExperience` records without an admission node.
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
    judged =
      if graph,
        do: admissions(graph),
        else: %{
          "admitted" => [],
          "invalid" => [],
          "not_admitted" => [],
          "without_admission" => []
        }

    considered = judged["admitted"]

    with :ok <- verified(judged, row),
         {:ok, applicable} <- applicable(considered, row) do
      decide(row, judged, applicable)
    end
  end

  defp verified(%{"invalid" => []}, _row), do: :ok

  defp verified(%{"invalid" => invalid} = judged, row) do
    {:refused,
     typed(
       "REFUSED(experience_admission_invalid)",
       "experience_admission_invalid",
       "mu_on_O",
       "route",
       %{
         "order" => row["identity"],
         "invalid" => invalid,
         "experiences_considered" => Enum.map(judged["admitted"], & &1["machine_experience"])
       }
     )}
  end

  defp applicable(considered, row) do
    Enum.reduce_while(considered, {:ok, []}, fn experience, {:ok, acc} ->
      case applicability(experience["applicability_predicate"], row) do
        {:ok, true} ->
          if within_bounds?(experience["consequence_bounds"], row),
            do: {:cont, {:ok, acc ++ [experience]}},
            else: {:cont, {:ok, acc}}

        {:ok, false} ->
          {:cont, {:ok, acc}}

        {:error, error} ->
          {:halt,
           {:refused,
            typed(
              "REFUSED(experience_predicate_unevaluable)",
              "experience_predicate_unevaluable",
              "mu_on_O",
              "route",
              %{
                "order" => row["identity"],
                "machine_experience" => experience["machine_experience"],
                "admission" => experience["admission"],
                "predicate_sha256" => sha256(to_string(experience["applicability_predicate"])),
                "error" => error
              }
            )}}
      end
    end)
  end

  defp decide(row, judged, applicable) do
    detail = %{
      "order" => row["identity"],
      "failure_class" => row["failure_class"],
      "experiences_considered" => Enum.map(judged["admitted"], & &1["machine_experience"]),
      "experiences_applicable" => Enum.map(applicable, & &1["machine_experience"]),
      "admissions_not_admitted" => Enum.map(judged["not_admitted"], & &1["admission"]),
      "experiences_without_admission" => judged["without_admission"]
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
  CANDIDATE, authority NONE and sha256-shaped digests, graph-representable
  (non-blank scalar fields; observation refs a non-empty, sorted, unique
  list -- RDF keeps a set, so any other order could not be recomputed from
  the graph) and its `experience_digest` must recompute
  (`experience_digest/1`); every admission field must be a string, nil or
  (for the set-valued ones) a list of strings; every ARD section 15 field
  must be non-blank; the admitted capability must be canonical; the
  consequence bounds must decode; the applicability predicate must evaluate
  (`applicability/2`) and select its own source order, and the bounds must
  contain it; `evidence` must show an ALIVE drive whose independent court
  passed and whose revert falsifier killed; and the experience must come
  from a recorded, bounded exploration (PRD PR-016): `evidence["exploration"]`
  (`"digest"`, `"budget"`, `"used"`) is bound to the fields'
  `source_exploration` digest and its usage is within every budget
  dimension (`Exploration.within_budget/2`) -- an over-budget exploration
  never becomes an admitted experience. `{:ok, admission}` (the fields in
  graph normal form, `admission_form/1`, plus `"admission" => "ADMITTED"`
  and `"admission_digest"`, `admission_digest/2` over it and the whole
  record) or `{:refused, typed}` (broken term `admission_vacuous`) naming
  the first failed condition, in the order above. The record and admission
  checks are the ones `admissions/1` re-runs on the graph at routing time.
  """
  @spec admit(map(), map(), map(), map()) :: {:ok, map()} | {:refused, map()}
  def admit(experience, fields, row, evidence) do
    drive = evidence["drive"] || %{}
    verification = evidence["verification"] || %{}

    # Lazy: each condition runs only when every earlier one held, so a later
    # condition never evaluates inputs an earlier one already refused.
    checks =
      record_checks(experience) ++
        [fn -> field_types(fields) end] ++
        admission_checks(fields) ++
        [
          fn -> predicate_selects_source(fields["applicability_predicate"], row) end,
          fn ->
            check(
              within_bounds?(decode(fields["consequence_bounds"]), row),
              "bounds_exclude_source",
              %{"order" => row["identity"]}
            )
          end,
          fn ->
            check(drive["standing"] == "ALIVE", "source_not_alive", %{
              "standing" => drive["standing"]
            })
          end,
          fn ->
            check(
              get_in(verification, ["independent", "status"]) == "pass" and
                get_in(verification, ["revert_falsifier", "verdict"]) == "killed",
              "source_unverified",
              %{
                "independent" => get_in(verification, ["independent", "status"]),
                "revert_falsifier" => get_in(verification, ["revert_falsifier", "verdict"])
              }
            )
          end,
          fn -> bounded_exploration(fields["source_exploration"], evidence["exploration"]) end
        ]

    case first_refusal(checks) do
      :ok ->
        admission = fields |> Map.put("admission", "ADMITTED") |> admission_form()
        {:ok, Map.put(admission, "admission_digest", admission_digest(experience, admission))}

      {:refuse, reason, detail} ->
        {:refused, typed("REFUSED(#{reason})", reason, "admission_vacuous", "admit", detail)}
    end
  end

  # every admission field is what its RDF rendering can carry back: nil or a
  # string, or (set-valued fields) a list of strings -- never a value
  # admission_form/1 would silently drop
  defp field_types(fields) do
    malformed =
      @admission_fields
      |> Enum.map(&elem(&1, 0))
      |> Enum.reject(&(&1 in ~w(admission admission_digest)))
      |> Enum.reject(fn key ->
        value = fields[key]

        if key in @admission_list_fields,
          do: is_nil(value) or (is_list(value) and Enum.all?(value, &is_binary/1)),
          else: is_nil(value) or is_binary(value)
      end)

    check(malformed == [], "admission_field_malformed", %{"fields" => malformed})
  end

  defp drop_attempts(%{} = used), do: Map.drop(used, ["attempts"])
  defp drop_attempts(used), do: used

  defp check(true, _reason, _detail), do: :ok
  defp check(false, reason, detail), do: {:refuse, reason, detail}

  defp predicate_selects_source(predicate, row) do
    case applicability(predicate, row) do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        {:refuse, "predicate_excludes_source", %{"order" => row["identity"]}}

      {:error, error} ->
        {:refuse, "predicate_unevaluable", %{"order" => row["identity"], "error" => error}}
    end
  end

  defp bounded_exploration(source_exploration, exploration) do
    cond do
      not nonblank?(source_exploration) or not is_map(exploration) ->
        {:refuse, "exploration_unrecorded",
         %{
           "source_exploration" => source_exploration,
           "exploration" => if(is_map(exploration), do: "present", else: "absent")
         }}

      exploration["digest"] != source_exploration ->
        {:refuse, "exploration_unbound",
         %{
           "source_exploration" => source_exploration,
           "exploration_digest" => exploration["digest"]
         }}

      true ->
        case Exploration.within_budget(exploration, exploration["used"]) do
          :ok ->
            :ok

          {:exhausted, which} ->
            {:refuse, "exploration_over_budget",
             %{
               "exhausted" => which,
               "budget" => exploration["budget"],
               "used" => drop_attempts(exploration["used"])
             }}
        end
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

  defp to_string_or_empty(value) when is_binary(value), do: value
  defp to_string_or_empty(_value), do: ""

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
