defmodule Xaas.CaseStudies.WdFaStogafSemanticFilesTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)
  @pack Path.join(@root, "priv/packs/wd_cs2_pack")

  test "core semantic vocabulary declares RDF before using rdf:Property" do
    core = read!("stogaf-core.ttl")

    assert core =~ "@prefix rdf:"
    assert core =~ "rdf:Property"
    assert core =~ "stogaf:ST9"
  end

  test "SHACL shapes bind architecture episode, views and MachineExperience" do
    shapes = read!("stogaf-shapes.ttl")

    assert shapes =~ "@prefix prov:"
    assert shapes =~ "ArchitectureEpisodeShape"
    assert shapes =~ "MachineExperienceShape"
    assert shapes =~ "ViewShape"
  end

  test "authority gate refuses production-level promotion" do
    gate = read!(Path.join("gates", "020_authority_ceiling.rq"))

    assert gate =~ "SELECT_CONSTRUCT_ONLY"
    assert gate =~ "ENGINEER_DISPOSITION_REQUIRED"
    assert gate =~ "ST-7 ACTUATED"
    assert gate =~ "unobserved-production-conformance-claimed"
  end

  test "requirement and experience gates fail closed on missing proof" do
    requirements = read!(Path.join("gates", "050_requirement_traceability.rq"))
    experience = read!(Path.join("gates", "040_machine_experience.rq"))

    assert requirements =~ "requirement-has-no-verification-court"
    assert requirements =~ "requirement-has-no-standing"
    assert experience =~ "machine-experience-missing-replay-identity"
    assert experience =~ "machine-experience-missing-receipt"
  end

  defp read!(relative), do: File.read!(Path.join(@pack, relative))
end
