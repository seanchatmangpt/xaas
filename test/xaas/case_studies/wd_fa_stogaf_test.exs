defmodule Xaas.CaseStudies.WdFaStogafTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.Stogaf

  test "conformance ladder is complete and ordered" do
    assert Enum.map(Stogaf.conformance_levels(), & &1.id) ==
             Enum.map(0..9, &"ST-#{&1}")

    assert hd(Stogaf.conformance_levels()).name == "DOCUMENTED"
    assert List.last(Stogaf.conformance_levels()).name == "LEARNING"
  end

  test "demo standing is evidence-bounded below actuation" do
    projection = Stogaf.demo_projection()

    assert projection.current_conformance == "ST-4 CONSTRAINED"
    assert projection.target_conformance == "ST-6 AUTONOMIC"
    assert projection.authority == "SELECT_CONSTRUCT_ONLY"
    assert projection.human_gate == "ENGINEER_DISPOSITION_REQUIRED"
    assert projection.evidence_ceiling == "REPO_LOCAL_FIXTURE"
    refute projection.current_conformance =~ "ACTUATED"
  end

  test "ADM implementation governance transitions to architecture change management" do
    projection = Stogaf.demo_projection()
    phases = Stogaf.adm_phases()

    assert projection.current_adm_phase == "G IMPLEMENTATION_GOVERNANCE"
    assert projection.next_adm_phase == "H ARCHITECTURE_CHANGE_MANAGEMENT"
    assert phases["G"] =~ "exact-head"
    assert phases["H"] =~ "MachineExperience"
  end

  test "architecture views and work remain projections of canonical state" do
    projection = Stogaf.demo_projection()

    assert projection.equation == "A = μ(O*)"
    assert projection.canonical_state == "O*"
    assert projection.work_projection == "sJira"
    assert projection.capability_projection == "SA2A"
    assert "MorningBriefView" in projection.building_blocks
    assert "MachineExperience" in projection.building_blocks
  end

  test "conformance refuses to promote unobserved production standing" do
    by_level = Map.new(Stogaf.conformance_status(), &{&1.level, &1})

    assert by_level["ST-4"].standing == "ALIVE"
    assert by_level["ST-5"].standing == "PARTIAL_ALIVE"
    assert by_level["ST-6"].standing == "PARTIAL_ALIVE"
    assert by_level["ST-7"].standing == "UNKNOWN"
    assert by_level["ST-8"].standing == "UNKNOWN"
    assert by_level["ST-9"].standing == "UNKNOWN"
  end

  test "normative STOGAF invariants preserve authority and evidence discipline" do
    invariants = Stogaf.invariants() |> Enum.join("\n")

    assert invariants =~ "graph is law"
    assert invariants =~ "Candidate ranking does not create authority"
    assert invariants =~ "Missing required evidence"
    assert invariants =~ "MachineExperience requires verified consequence"
  end
end
