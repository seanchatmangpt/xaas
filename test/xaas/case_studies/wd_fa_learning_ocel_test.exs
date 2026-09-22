defmodule Xaas.CaseStudies.WdFaLearningOcelTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "full learning episode persists work, disposition, receipt, experience and standard change" do
    result = WdFa.seed_learning_ocel!()
    projection = result.projection

    assert projection["eventTypes"] == [
             "diagnostic_work_constructed",
             "engineer_disposition_observed",
             "failure_observed",
             "machine_experience_admitted",
             "standard_updated",
             "triage_constructed",
             "verification_receipt_observed"
           ]

    for type <- [
          "FailureCase",
          "Drive",
          "StandardWork",
          "SemanticWorkOrder",
          "EngineerDisposition",
          "VerificationReceipt",
          "MachineExperience"
        ] do
      assert type in projection["objectTypes"]
    end

    assert result.receipt.authority_scope == "REPO_LOCAL_FIXTURE"
    assert result.experience.id == "MX-NOVEL-X-001"
    assert result.architecture_change.from_standard == "CS2-V1"
    assert result.architecture_change.to_standard == "CS2-V2"
    assert result.architecture_change.authority == "CONSTRUCT_ONLY"
  end
end
