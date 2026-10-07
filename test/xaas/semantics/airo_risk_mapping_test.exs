defmodule Xaas.Semantics.AiroRiskMappingTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.AiroRiskMapping

  @ledger_count 71

  test "emits a graph string" do
    graph = AiroRiskMapping.risk_graph()
    assert is_binary(graph)
    assert String.contains?(graph, "airo:AISystem")
  end

  test "deterministic across two runs" do
    assert AiroRiskMapping.risk_graph() == AiroRiskMapping.risk_graph()
  end

  test "covers every ledger variant (one RiskSource per variant)" do
    vs = AiroRiskMapping.variants()
    assert length(vs) == @ledger_count

    graph = AiroRiskMapping.risk_graph()

    for v <- vs do
      assert String.contains?(graph, ~s(ex:refusalVariant "#{v.variant}")),
             "missing variant #{v.variant}"
    end
  end

  test "70 REFUSED_* + 1 BLOCKED_* in the ledger" do
    vs = AiroRiskMapping.variants()
    assert Enum.count(vs, & &1.refused?) == 70
    assert Enum.count(vs, &(not &1.refused?)) == 1
  end

  test "every RiskControl cites an existing module path" do
    for c <- AiroRiskMapping.risk_controls() do
      assert File.exists?(Path.expand(c.path, File.cwd!())),
             "missing module path #{c.path}"
      assert String.contains?(AiroRiskMapping.risk_graph(), ~s(ex:modulePath "#{c.path}"))
    end
  end

  test "AIRo namespace prefix declared and structural parse sanity" do
    graph = AiroRiskMapping.risk_graph()

    assert String.contains?(graph, "@prefix airo: <https://w3id.org/airo#>")
    assert String.contains?(graph, "airo:RiskSource")
    assert String.contains?(graph, "airo:Hazard")
    assert String.contains?(graph, "airo:RiskControl")
    assert String.contains?(graph, "airo:detectsRiskConcept")
    assert String.contains?(graph, "airo:mitigatesRiskConcept")
    assert String.contains?(graph, "airo:hasRisk ")

    # structural sanity: no empty-predicate or double-terminator artifacts
    refute String.contains?(graph, ";;")
    refute String.contains?(graph, " . .")
    assert String.ends_with?(graph, ".\n")
    assert String.contains?(graph, "airo:AIDeployer")
  end

  @tag skip: "rdflib parse venv (/tmp/airo-venv) is ephemeral and not provisioned — RDF round-trip parse was witnessed for real by the W601 receipt (docs/sjira/v26.10.6/plans/w601-airo-mapping.md: rdflib 7.6.0 round-trip inside this test)"
  test "rdflib round-trip parse when a parser is available" do
    graph = AiroRiskMapping.risk_graph()
    path = Path.join(System.tmp_dir!(), "w601-airo-risk-graph.ttl")
    File.write!(path, graph)

    # Only select interpreters that actually exist; a truthy path string for a
    # missing venv binary previously shelled out to exit 127 and crashed the
    # {out, 0} match (W658 environment defect).
    py =
      Enum.find(
        ["/tmp/airo-venv/bin/python", System.find_executable("python3")],
        &(&1 && File.exists?(&1))
      )

    unless py, do: throw({:skip, "no python interpreter available"})

    parse_script = """
    import sys
    try:
        import rdflib
    except ImportError:
        print("SKIP: rdflib unavailable")
        sys.exit(0)
    g = rdflib.Graph()
    g.parse(sys.argv[1], format="turtle")
    print("TRIPLES=%d" % len(g))
    """

    {out, 0} = System.shell("#{py} #{py_script_path(parse_script)} #{path}")
    IO.puts(out)
    refute String.contains?(out, "Traceback")
  end

  test "W657 EUAIA family: each Art. 5 atom maps to its distinct risk concept" do
    expected = %{
      "REFUSED_EUAIA_MANIPULATIVE" => "RISK_TO_INFORMED_CHOICE",
      "REFUSED_EUAIA_VULNERABILITY_EXPLOIT" => "RISK_TO_VULNERABLE_PERSONS",
      "REFUSED_EUAIA_SOCIAL_SCORING" => "CROSS_CONTEXT_RISK",
      "REFUSED_EUAIA_PREDICTIVE_POLICING" => "DUE_PROCESS_RISK",
      "REFUSED_EUAIA_FACIAL_SCRAPING" => "PRIVACY_RISK",
      "REFUSED_EUAIA_EMOTION_RECOGNITION" => "MENTAL_PRIVACY_RISK",
      "REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION" => "DISCRIMINATION_RISK",
      "REFUSED_EUAIA_REALTIME_RBI" => "SURVEILLANCE_RISK"
    }

    for {atom, concept} <- expected do
      assert AiroRiskMapping.risk_concept_for(atom) == concept
      # determinism
      assert AiroRiskMapping.risk_concept_for(atom) == concept
    end

    # the 8 concepts are pairwise distinct
    assert MapSet.size(MapSet.new(Map.values(expected))) == 8

    # malformed-input class
    assert AiroRiskMapping.risk_concept_for("REFUSED_EUAIA_MALFORMED_CANDIDATE") ==
             "MALFORMED_INPUT_CANDIDATE"

    # non-EUAIA variants keep their existing families (composition intact)
    assert AiroRiskMapping.risk_concept_for("REFUSED_CASTLE_AUTHORITY_ESCAPE") ==
             "AUTHORITY_ESCAPE"

    # BLOCKED_UNRECEIPTED_ACTUATION is the receipt-integrity refusal family:
    # the variant name contains "RECEIPT", so it maps to RECEIPT_INTEGRITY_FAILURE
    # (an actuation blocked for lack of a receipt), not the catch-all fallback.
    assert AiroRiskMapping.risk_concept_for("BLOCKED_UNRECEIPTED_ACTUATION") ==
             "RECEIPT_INTEGRITY_FAILURE"
  end

  test "W657 EUAIA atoms are emitted as RiskSources in the risk graph" do
    graph = AiroRiskMapping.risk_graph()

    for concept <- [
          "RISK_TO_INFORMED_CHOICE",
          "RISK_TO_VULNERABLE_PERSONS",
          "CROSS_CONTEXT_RISK",
          "DUE_PROCESS_RISK",
          "PRIVACY_RISK",
          "MENTAL_PRIVACY_RISK",
          "DISCRIMINATION_RISK",
          "SURVEILLANCE_RISK"
        ] do
      assert String.contains?(graph, "mapsToRiskConcept ex:#{concept}"),
             "concept #{concept} not emitted by the risk graph"
    end
  end

  defp py_script_path(content) do
    path = Path.join(System.tmp_dir!(), "w601-parse.py")
    File.write!(path, content)
    path
  end
end
