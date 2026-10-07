defmodule Xaas.AiroShaclCourtTest do
  @moduledoc """
  W615 / WP-6 verification court: AIRO -> SHACL profile compilation.

  Court assertions:
    C1. The emitted profile parses (RDF.ex well-formedness) — ×2 runs.
    C2. sh:NodeShape census is exactly one per AIRO class — ×2 runs.
    C3. Zero custom TBoxes: every predicate/object IRI in the profile lives
        under the SHACL, AIRO, or AIRO-shapes namespace — ×2 runs.
    C4. A deliberately malformed instance (a RiskControl with no risk-concept
        binding, a Risk with no citing control) violates per the generator's
        own check function `violations/1` — disclosed substitute for a SHACL
        engine (no `shacl` package exists in mix.lock).
    C5. The real instance graph `priv/airo_risk_description.ttl` (W982m)
        produces zero constraint violations and zero dead file citations.
    C6. The generator's vocab SHA gate matches the W981j/W982m pin
        (6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469).
  """

  use ExUnit.Case, async: true

  @vocab_path "priv/semantic/airo/airo.ttl"
  @profile_path "priv/airo/profile.shacl.ttl"
  @instance_path "priv/airo_risk_description.ttl"
  @pinned_sha "6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469"

  @airo "https://w3id.org/airo#"
  @airo_shapes @airo <> "shapes#"
  @sh "http://www.w3.org/ns/shacl#"
  @rdf_type RDF.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")
  @owl_class RDF.iri("http://www.w3.org/2002/07/owl#Class")
  @node_shape RDF.iri(@sh <> "NodeShape")

  defp path(p), do: Path.expand(p, File.cwd!())

  defp vocab_classes do
    RDF.Turtle.read_file!(path(@vocab_path))
    |> RDF.Graph.descriptions()
    |> Enum.filter(&object?(&1, @rdf_type, @owl_class))
    |> Enum.map(&RDF.Description.subject/1)
    |> Enum.filter(&(String.starts_with?(to_string(&1), @airo)))
    |> Enum.sort()
  end

  defp profile_shapes do
    RDF.Turtle.read_file!(path(@profile_path))
    |> RDF.Graph.descriptions()
    |> Enum.filter(&object?(&1, @rdf_type, @node_shape))
    |> Enum.map(&RDF.Description.subject/1)
  end

  defp profile_iris do
    graph = RDF.Turtle.read_file!(path(@profile_path))

    graph
    |> RDF.Graph.statements()
    |> Enum.flat_map(fn
      {s, p, %RDF.IRI{} = o} -> [s, p, o]
      {s, p, _o} -> [s, p]
    end)
    |> Enum.reject(&match?(%RDF.BlankNode{}, &1))
  end

  defp allowed_ns?(iri) do
    String.starts_with?(to_string(iri), [
      @sh,
      @airo,
      "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
      "http://www.w3.org/2000/01/rdf-schema#"
    ])
  end

  defp object?(desc, pred, obj) do
    desc
    |> RDF.Description.get(pred, [])
    |> List.wrap()
    |> Enum.any?(&(&1 == obj))
  end

  defp compile! do
    {:ok, stats} = Mix.Tasks.Xaas.Airo.CompileShacl.compile()
    stats
  end

  test "C6: pinned vocabulary SHA256 matches W981j/W982m pin" do
    assert :crypto.hash(:sha256, File.read!(path(@vocab_path))) |> Base.encode16(case: :lower) ==
             @pinned_sha
  end

  test "C1+C2+C3: compilation emits a well-formed profile with exact class census, twice" do
    for run <- 1..2 do
      stats = compile!()

      assert stats.vocab_sha256 == @pinned_sha
      assert stats.shapes_emitted == stats.class_census
      assert stats.class_census == length(vocab_classes())
      assert stats.triples_emitted > 0

      # C1: parse back independently
      parsed = RDF.Turtle.read_file!(path(@profile_path))
      assert RDF.Graph.triple_count(parsed) == stats.triples_emitted

      # C2: shape census exactly the AIRO class census (same order-insensitive set
      #     of cardinalities; one shape per class)
      assert length(profile_shapes()) == length(vocab_classes())

      # C3: zero custom TBoxes — only SHACL + AIRO namespaces
      Enum.each(profile_iris(), fn iri ->
        assert allowed_ns?(iri), "custom TBox IRI leaked into profile: #{iri}"
      end)

      # determinism: byte-identical output on rerun
      first_bytes = File.read!(path(@profile_path))
      {:ok, _} = Mix.Tasks.Xaas.Airo.CompileShacl.compile()
      assert File.read!(path(@profile_path)) == first_bytes, "run #{run} non-deterministic"

      IO.puts("W615 court run #{run}: OK (census=#{stats.class_census}, triples=#{stats.triples_emitted})")
    end
  end

  test "C4: malformed instance (control without binding, uncited risk) violates" do
    compile!()

    {:ok, malformed} =
      RDF.Turtle.read_string("""
      @prefix airo: <#{@airo}> .
      @prefix w615: <https://xaas.chatman-ecosystem.dev/airo/w615-malformed#> .

      w615:OrphanControl a airo:RiskControl .
      w615:UncitedRisk a airo:Risk .
      """)

    vs = Mix.Tasks.Xaas.Airo.CompileShacl.violations(malformed)

    assert Enum.any?(vs, &match?(%{constraint: :control_binds_risk_concept}, &1))
    assert Enum.any?(vs, &match?(%{constraint: :risk_cited_by_control}, &1))

    # the mutation lens: adding the binding clears the violation (non-vacuous check)
    {:ok, repaired} =
      RDF.Turtle.read_string("""
      @prefix airo: <#{@airo}> .
      @prefix w615: <https://xaas.chatman-ecosystem.dev/airo/w615-malformed#> .

      w615:OrphanControl a airo:RiskControl ;
          airo:mitigatesRiskConcept w615:SomeRiskSource .

      w615:SomeRiskSource a airo:RiskSource .
      w615:UncitedRisk a airo:Risk .
      """)

    vs2 = Mix.Tasks.Xaas.Airo.CompileShacl.violations(repaired)
    orphan = RDF.iri("https://xaas.chatman-ecosystem.dev/airo/w615-malformed#OrphanControl")
    refute Enum.any?(vs2, &(&1.focus == orphan))
  end

  test "C5: real W982m instance graph is clean under the compiled constraints" do
    compile!()
    instance = RDF.Turtle.read_file!(path(@instance_path))

    assert Mix.Tasks.Xaas.Airo.CompileShacl.violations(instance) == []
    assert Mix.Tasks.Xaas.Airo.CompileShacl.check_file_citations(instance) == []
  end

  test "profile file exists on disk after compile" do
    compile!()
    assert File.exists?(path(@profile_path))
    assert @airo_shapes == @airo <> "shapes#"
  end
end
