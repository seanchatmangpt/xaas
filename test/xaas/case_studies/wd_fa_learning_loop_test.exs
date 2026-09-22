defmodule Xaas.CaseStudies.WdFaLearningLoopTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa
  alias Xaas.CaseStudies.WdFa.LearningLoop

  test "UNKNOWN fixture becomes reusable experience only after independent verification" do
    assert WdFa.presentation_state("novel_x").classification == "UNKNOWN"
    assert {:ok, %{receipt: receipt, experience: experience}} = LearningLoop.verify_novel_fixture()

    assert receipt.observed_disposition == "MODE-X-NOVEL"
    assert experience.mode_id == "MODE-X-NOVEL"
    assert experience.evidence_ceiling == "REPO_LOCAL_FIXTURE"
    assert experience.replay_identity == "NOVEL-X-REPLAY"
    assert WdFa.presentation_state("novel_x", true).classification == "KNOWN"
  end

  test "MachineExperience compilation refuses disposition mismatch" do
    assert {:ok, %{receipt: receipt}} = LearningLoop.verify_novel_fixture()
    assert {:error, :disposition_binding_failed} = LearningLoop.compile(receipt, "MODE-WRONG")
  end
end
