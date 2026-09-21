defmodule Xaas.Gall.TurtleTest do
  use ExUnit.Case, async: true

  alias Xaas.Gall.Checkpoint
  alias Xaas.Gall.Turtle

  @base_sha "6d5fca8cff223eb30ef19e237574d54f21cbfc15"

  @canonical_ttl """
  @prefix gall: <https://semantic-a2a.dev/gall#> .

  <urn:gall:checkpoint:xaas:semantic-worker-001>
    a gall:CodingCheckpoint ;
    gall:repository <urn:repo:seanchatmangpt:xaas> ;
    gall:baseSha "#{@base_sha}" ;
    gall:goal gall:SemanticWorkerIntegration ;
    gall:requiresCapability gall:Read, gall:Edit, gall:Commit ;
    gall:forbidsCapability gall:Push, gall:Publish ;
    gall:requiresVerifier gall:XaasChicagoCourt ;
    gall:standing gall:UNKNOWN .
  """

  @equivalent_json_fields [
    identity: "urn:gall:checkpoint:xaas:semantic-worker-001",
    class: "CodingCheckpoint",
    repository: "urn:repo:seanchatmangpt:xaas",
    base_sha: @base_sha,
    goal: "https://semantic-a2a.dev/gall#SemanticWorkerIntegration",
    requires_capabilities: [:Read, :Edit, :Commit],
    forbids_capabilities: [:Push, :Publish],
    verifier: "https://semantic-a2a.dev/gall#XaasChicagoCourt",
    standing: :UNKNOWN
  ]

  describe "from_turtle/1" do
    test "the real RDF.Turtle parser is loadable in this environment (dev/test dep graph)" do
      assert Code.ensure_loaded?(RDF.Turtle),
             "the TTL path is supposed to be REAL in dev/test (rdf arrives transitively via ggen_igniter)"
    end

    test "admits the canonical PRD reference TTL form" do
      assert {:ok, checkpoint} = Turtle.from_turtle(@canonical_ttl)

      assert checkpoint.identity == "urn:gall:checkpoint:xaas:semantic-worker-001"
      assert checkpoint.class == "CodingCheckpoint"
      assert checkpoint.repository == "urn:repo:seanchatmangpt:xaas"
      assert checkpoint.base_sha == @base_sha
      assert checkpoint.goal == "https://semantic-a2a.dev/gall#SemanticWorkerIntegration"
      # RDF graph enumeration order is not document order; capabilities are
      # a set (the digest sorts them), so compare as sets.
      assert Enum.sort(checkpoint.requires_capabilities) == [:Commit, :Edit, :Read]
      assert Enum.sort(checkpoint.forbids_capabilities) == [:Publish, :Push]
      assert checkpoint.verifier == "https://semantic-a2a.dev/gall#XaasChicagoCourt"
      assert checkpoint.standing == :UNKNOWN
    end

    test "TTL and JSON admission surfaces produce the IDENTICAL graph digest" do
      {:ok, from_ttl} = Turtle.from_turtle(@canonical_ttl)
      {:ok, from_json} = Checkpoint.new(@equivalent_json_fields)

      assert Checkpoint.graph_digest(from_ttl) == Checkpoint.graph_digest(from_json)
    end

    test "admits optional multi-valued predicates (dependencies, paths, acceptance, policy)" do
      ttl = """
      @prefix gall: <https://semantic-a2a.dev/gall#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <urn:gall:checkpoint:xaas:semantic-worker-001>
        a gall:CodingCheckpoint ;
        gall:repository <urn:repo:seanchatmangpt:xaas> ;
        gall:baseSha "#{@base_sha}" ;
        gall:goal gall:SemanticWorkerIntegration ;
        gall:requiresVerifier gall:XaasChicagoCourt ;
        gall:standing gall:UNKNOWN ;
        gall:dependency <urn:gall:checkpoint:xaas:foundation-001> ;
        gall:allowedPath "lib/xaas/**" ;
        gall:acceptance "mix test test/xaas/gall" ;
        gall:falsifier "admit an unregistered capability" ;
        gall:requiredEvidence "focused mix test exit 0" ;
        gall:executionPolicy '{"max_parallel": 4}'^^xsd:string .
      """

      assert {:ok, checkpoint} = Turtle.from_turtle(ttl)

      assert checkpoint.dependencies == ["urn:gall:checkpoint:xaas:foundation-001"]
      assert checkpoint.allowed_paths == ["lib/xaas/**"]
      assert checkpoint.acceptance == ["mix test test/xaas/gall"]
      assert checkpoint.falsifiers == ["admit an unregistered capability"]
      assert checkpoint.required_evidence == ["focused mix test exit 0"]
      assert checkpoint.execution_policy == %{"max_parallel" => 4}
    end

    test "returns an admission refusal tuple for TTL encoding an invalid checkpoint" do
      bad_capability_ttl = String.replace(@canonical_ttl, "gall:Commit", "gall:Teleport")

      assert Turtle.from_turtle(bad_capability_ttl) == {:refused, :refused_capability}
    end

    test "returns {:error, {:ttl_decode_failed, _}} for unparseable Turtle" do
      assert {:error, {:ttl_decode_failed, _reason}} =
               Turtle.from_turtle("this is not turtle @ all <<<")
    end

    test "returns {:error, :no_checkpoint_subject} when no CodingCheckpoint subject exists" do
      other_ttl = """
      @prefix gall: <https://semantic-a2a.dev/gall#> .

      <urn:gall:checkpoint:xaas:not-a-checkpoint>
        a gall:SomethingElse ;
        gall:standing gall:UNKNOWN .
      """

      assert Turtle.from_turtle(other_ttl) == {:error, :no_checkpoint_subject}
    end

    test "returns multiple-subject error when more than one checkpoint is in one document" do
      second =
        String.replace(
          @canonical_ttl,
          "urn:gall:checkpoint:xaas:semantic-worker-001",
          "urn:gall:checkpoint:xaas:semantic-worker-002"
        )

      assert {:error, {:multiple_checkpoint_subjects, 2}} =
               Turtle.from_turtle(@canonical_ttl <> "\n" <> second)
    end

    test "refuses non-binary input instead of crashing" do
      assert Turtle.from_turtle(nil) == {:error, :ttl_parser_unavailable}
      assert Turtle.from_turtle(123) == {:error, :ttl_parser_unavailable}
    end
  end
end
