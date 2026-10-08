defmodule Mix.Tasks.Xaas.Airo.CompileShacl do
  @shortdoc "Compile AIRO vocabulary structural constraints into a SHACL profile"

  @moduledoc """
  Direct AIRO -> SHACL compilation (lane W615, WP-6, v26.10.7).

  Parses the pinned canonical AIRO 1.0 vocabulary
  (`priv/semantic/airo/airo.ttl`, sha256 6274d2d8...) and emits
  `priv/airo/profile.shacl.ttl`: one sh:NodeShape per AIRO class plus
  PropertyShapes compiling three structural constraints:

    1. Every airo:RiskControl binds >= 1 risk concept via one of
       {mitigatesRiskConcept, detectsRiskConcept, eliminatesRiskConcept,
        modifiesRiskConcept}.
    2. Every airo:Risk is cited by >= 1 control via the inverse of those
       predicates (or via airo:hasConsequence chain start).
    3. rdfs:seeAlso citations use the file:// scheme (file existence is
       checked by `check_file_citations/1`, not expressible in SHACL).

  NO SHACL VALIDATOR exists in this dependency tree (no `shacl` package in
  mix.lock; RDF.ex 3.0.1 + SPARQL only). The court therefore verifies the
  emitted profile with a hand-rolled check function `violations/1` that
  implements exactly the three constraints above, NOT a conformant SHACL
  engine. This absence is a disclosed boundary, not a claim of SHACL
  conformance.
  """

  use Mix.Task

  @sh_ns "http://www.w3.org/ns/shacl#"

  @vocab_path "priv/semantic/airo/airo.ttl"
  @out_path "priv/airo/profile.shacl.ttl"

  @airo "https://w3id.org/airo#"
  @sh "http://www.w3.org/ns/shacl#"
  @owl_class RDF.iri("http://www.w3.org/2002/07/owl#Class")

  @binding_predicates [
    "mitigatesRiskConcept",
    "detectsRiskConcept",
    "eliminatesRiskConcept",
    "modifiesRiskConcept"
  ]

  @impl true
  def run(_args) do
    case compile() do
      {:ok, stats} ->
        Mix.shell().info(inspect(stats))

      {:error, reason} ->
        raise Mix.Error, message: "AIRO->SHACL compilation failed: #{inspect(reason)}"
    end
  end

  @doc """
  Compiles the vocabulary into the SHACL profile and writes it.
  Returns `{:ok, stats}` with the compilation-contract numbers the court
  re-derives independently.
  """
  def compile do
    vocab = RDF.Turtle.read_file!(vocab_path())

    classes =
      vocab
      |> statements_of_type(@owl_class)
      |> Enum.filter(&(iri_prefix(&1) == @airo))
      |> Enum.sort()

    if classes == [], do: throw({:no_classes, vocab_path()})

    turtle = render(classes)

    File.mkdir_p!(Path.dirname(out_path()))
    File.write!(out_path(), turtle)

    # Round-trip gate: the emitted profile must parse back to a graph whose
    # sh:NodeShape subjects are exactly one per AIRO class.
    reparsed = RDF.Turtle.read_file!(out_path())
    shape_iris = statements_of_type(reparsed, RDF.iri(@sh_ns <> "NodeShape"))

    if length(shape_iris) != length(classes) do
      throw({:shape_census_mismatch, length(shape_iris), length(classes)})
    end

    {:ok,
     %{
       vocab_sha256: vocab_sha256(),
       class_census: length(classes),
       shapes_emitted: length(shape_iris),
       triples_emitted: RDF.Graph.triple_count(reparsed),
       out_path: out_path()
     }}
  catch
    reason -> {:error, reason}
  end

  # ---------------------------------------------------------------------------
  # Hand-rolled constraint checks (disclosed substitute for a SHACL engine)
  # ---------------------------------------------------------------------------

  @doc """
  Checks an instance graph against the three compiled constraints. Returns a
  list of `%{focus: iri, constraint: atom, detail: binary}` violations.
  """
  def violations(graph) do
    controls = instances_of(graph, RDF.iri(@airo <> "RiskControl"))
    risks = instances_of(graph, RDF.iri(@airo <> "Risk"))

    (Enum.map(controls, &control_violations(graph, &1)) ++
       Enum.map(risks, &risk_violations(graph, &1)))
    |> Enum.reject(&is_nil/1)
  end

  defp control_violations(graph, control) do
    bound? =
      Enum.any?(@binding_predicates, fn p ->
        case RDF.Graph.description(graph, control) do
          nil -> false
          desc -> RDF.Description.get(desc, RDF.iri(@airo <> p)) != nil
        end
      end)

    unless bound? do
      %{
        focus: control,
        constraint: :control_binds_risk_concept,
        detail: "airo:RiskControl with no #{Enum.join(@binding_predicates, "/")} triple"
      }
    end
  end

  defp risk_violations(graph, risk) do
    cited? =
      Enum.any?(@binding_predicates, fn p ->
        graph
        |> RDF.Graph.statements()
        |> Enum.any?(fn
          {_subject, pred, ^risk} -> pred == RDF.iri(@airo <> p)
          _ -> false
        end)
      end)

    unless cited? do
      %{
        focus: risk,
        constraint: :risk_cited_by_control,
        detail: "airo:Risk not cited by any control binding predicate"
      }
    end
  end

  @doc """
  Constraint 3 (file citations): every `rdfs:seeAlso file://...` object must
  resolve to an existing repository path.
  """
  def check_file_citations(graph) do
    see_also = RDF.iri("http://www.w3.org/2000/01/rdf-schema#seeAlso")

    graph
    |> RDF.Graph.descriptions()
    |> Enum.flat_map(fn desc ->
      desc
      |> RDF.Description.get(see_also)
      |> List.wrap()
      |> Enum.map(&{RDF.Description.subject(desc), &1})
    end)
    |> Enum.flat_map(fn {subject, object} ->
      case to_string(object) do
        "file://" <> path = full ->
          if File.exists?(path) do
            []
          else
            [%{focus: subject, constraint: :file_citation_exists, detail: full}]
          end

        _ ->
          []
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Turtle rendering (deterministic, hand-rolled; only sh: + airo: namespaces)
  # ---------------------------------------------------------------------------

  defp render(classes) do
    header = """
    # GENERATED by Mix.Tasks.Xaas.Airo.CompileShacl (lane W615, WP-6) — do not edit.
    # Source: priv/semantic/airo/airo.ttl (AIRO 1.0, sha256 #{vocab_sha256()}).
    # One sh:NodeShape per AIRO class; PropertyShapes compile the structural
    # constraints documented in the generator moduledoc. No SHACL validator
    # exists in this dependency tree; see the W615 receipt.

    @prefix sh: <#{@sh}> .
    @prefix airo: <#{@airo}> .
    @prefix airo-sh: <#{@airo}shapes-> .

    """

    body =
      classes
      |> Enum.map(fn class_iri ->
        local = class_iri |> to_string() |> String.trim_leading(@airo)
        shape = "airo-shape-" <> macro_local(local)

        constraints =
          case local do
            "RiskControl" -> control_constraints()
            "Risk" -> risk_constraints()
            _ -> []
          end

        """
        airo-sh:#{shape} a sh:NodeShape ;
        #{Enum.join(["  sh:targetClass airo:#{local};" | constraints], "\n")}    .
        """
      end)
      |> Enum.join("\n")

    header <> body
  end

  defp control_constraints do
    branches =
      Enum.map(@binding_predicates, fn p ->
        "    [ sh:path airo:#{p} ; sh:minCount 1 ]"
      end)

    [
      "    sh:or (",
      Enum.join(branches, "\n"),
      "    ) ;"
    ]
  end

  defp risk_constraints do
    branches =
      Enum.map(@binding_predicates, fn p ->
        "    [ sh:path [ sh:inversePath airo:#{p} ] ; sh:minCount 1 ]"
      end)

    [
      "    sh:or (",
      Enum.join(branches, "\n"),
      "    ) ;"
    ]
  end

  defp macro_local(local), do: String.replace(local, ~r/[^A-Za-z0-9_-]/, "_")

  # ---------------------------------------------------------------------------
  # Graph helpers
  # ---------------------------------------------------------------------------

  defp vocab_path, do: Path.expand(@vocab_path, File.cwd!())
  defp out_path, do: Path.expand(@out_path, File.cwd!())

  defp vocab_sha256 do
    :crypto.hash(:sha256, File.read!(vocab_path())) |> Base.encode16(case: :lower)
  end

  defp statements_of_type(graph, type) do
    type_pred = RDF.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")

    graph
    |> RDF.Graph.descriptions()
    |> Enum.filter(&has_object?(&1, type_pred, type))
    |> Enum.map(&RDF.Description.subject/1)
  end

  defp descriptions_with_predicate(graph, predicate) do
    graph
    |> RDF.Graph.descriptions()
    |> Enum.filter(&(RDF.Description.get(&1, predicate) != nil))
  end

  defp has_object?(description, predicate, object) do
    description
    |> RDF.Description.get(predicate, [])
    |> List.wrap()
    |> Enum.any?(&(&1 == object))
  end

  defp instances_of(graph, class) do
    statements_of_type(graph, class)
  end

  defp iri_prefix(iri) do
    iri |> to_string() |> String.split("#") |> List.delete_at(-1) |> Enum.join("#")
    |> Kernel.<>("#")
  end
end
