defmodule Xaas.Semantics.ComputationTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.{ComputationArtifact, ComputationClaim, PlanningAdvice}

  defp artifact_attrs(runtime \\ "ONNX") do
    %{
      artifact_identity: "sha256:model-#{String.downcase(runtime)}",
      capability_iri: "https://schema.org/Action",
      runtime: runtime,
      input_schema_identity: "sha256:input-schema",
      output_schema_identity: "sha256:output-schema",
      input_projection_identity: "sha256:rdf-planning-projection",
      deterministic: true,
      training_corpus_identity: "sha256:ggen-corpus",
      calibration_identity: "sha256:calibration"
    }
  end

  test "runtime can vary while semantic capability remains stable" do
    assert {:ok, onnx} = ComputationArtifact.new(artifact_attrs("ONNX"))
    assert {:ok, nx} = ComputationArtifact.new(artifact_attrs("NX"))

    assert onnx.capability_iri == nx.capability_iri
    refute ComputationArtifact.hash(onnx) == ComputationArtifact.hash(nx)
  end

  test "any computation output remains a powerless candidate claim" do
    assert {:ok, artifact} = ComputationArtifact.new(artifact_attrs())

    assert {:ok, claim} =
             ComputationClaim.new(%{
               subject_identity: "sha256:planning-subject",
               predicate_iri: "https://schema.org/value",
               value: %{candidate: "rollback", score: 0.91},
               artifact: artifact,
               evidence_class: "INFERRED"
             })

    assert claim.standing == "CANDIDATE"
    refute claim.authorizes_actuation
    assert byte_size(ComputationClaim.hash(claim)) == 64

    assert {:error, {:computation_claim_standing_refused, "AUTHORIZED"}} =
             ComputationClaim.new(%{
               subject_identity: "sha256:planning-subject",
               predicate_iri: "https://schema.org/value",
               value: "rollback",
               artifact: artifact,
               evidence_class: "INFERRED",
               standing: "AUTHORIZED"
             })

    assert {:error, :computation_claim_cannot_authorize_actuation} =
             ComputationClaim.new(%{
               subject_identity: "sha256:planning-subject",
               predicate_iri: "https://schema.org/value",
               value: "rollback",
               artifact: artifact,
               evidence_class: "INFERRED",
               authorizes_actuation: true
             })
  end

  test "planning advice may reorder but cannot enlarge or prune the formal frontier" do
    assert {:ok, artifact} = ComputationArtifact.new(artifact_attrs())

    assert {:ok, advice} =
             PlanningAdvice.new(%{
               planning_subject_identity: "sha256:subject",
               formal_projection_identity: "sha256:fond-hddl",
               artifact: artifact,
               kind: "METHOD_ORDER",
               candidates: [
                 %{candidate_ref: "not-formal", score: 1.0},
                 %{candidate_ref: "failover", score: 0.72},
                 %{candidate_ref: "rollback", score: 0.91}
               ]
             })

    assert {:ok, ordered} =
             PlanningAdvice.order_formal(
               advice,
               ["restart", "rollback", "failover", "scale-out"]
             )

    assert ordered == ["rollback", "failover", "restart", "scale-out"]
    assert MapSet.new(ordered) ==
             MapSet.new(["restart", "rollback", "failover", "scale-out"])

    refute "not-formal" in ordered
    assert advice.standing == "CANDIDATE"
    refute advice.authorizes_actuation
  end

  test "private capability and predicate vocabularies are refused" do
    assert {:error, :non_public_capability_iri} =
             artifact_attrs()
             |> Map.put(:capability_iri, "urn:private:model-capability")
             |> ComputationArtifact.new()

    assert {:ok, artifact} = ComputationArtifact.new(artifact_attrs())

    assert {:error, :non_public_predicate_iri} =
             ComputationClaim.new(%{
               subject_identity: "sha256:subject",
               predicate_iri: "urn:private:prediction",
               value: 1,
               artifact: artifact,
               evidence_class: "INFERRED"
             })
  end

  test "runtime portability requires bounded output drift and identical ranking" do
    alias Xaas.Semantics.RuntimeEquivalence

    assert {:ok,
            %{
              passed: true,
              ranking_equal: true,
              reason: :runtime_equivalent
            }} =
             RuntimeEquivalence.qualify(
               %{"rollback" => 0.9, "failover" => 0.7},
               %{"rollback" => 0.9000001, "failover" => 0.6999999},
               1.0e-5
             )

    assert {:ok,
            %{
              passed: false,
              ranking_equal: false,
              reason: :runtime_output_drift
            }} =
             RuntimeEquivalence.qualify(
               %{"rollback" => 0.51, "failover" => 0.50},
               %{"rollback" => 0.49, "failover" => 0.52},
               0.05
             )
  end

end
