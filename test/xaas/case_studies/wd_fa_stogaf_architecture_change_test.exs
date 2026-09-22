defmodule Xaas.CaseStudies.WdFaStogafArchitectureChangeTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.LearningLoop
  alias Xaas.CaseStudies.WdFa.Stogaf.ArchitectureChange

  test "verified experience projects a Phase H architecture change" do
    assert {:ok, %{experience: experience}} = LearningLoop.verify_novel_fixture()
    assert {:ok, change} = ArchitectureChange.from_experience(experience)

    assert change.adm_phase == "H ARCHITECTURE_CHANGE_MANAGEMENT"
    assert change.trigger == "VERIFIED_MACHINE_EXPERIENCE"
    assert change.from_standard == "CS2-V1"
    assert change.to_standard == "CS2-V2"
    assert change.mode_id == "MODE-X-NOVEL"
    assert change.authority == "CONSTRUCT_ONLY"
    assert change.evidence_ceiling == "REPO_LOCAL_FIXTURE"
  end
end
