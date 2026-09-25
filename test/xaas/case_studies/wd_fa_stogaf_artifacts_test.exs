defmodule Xaas.CaseStudies.WdFaStogafArtifactsTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.Stogaf

  @root Path.expand("../../..", __DIR__)
  @case_dir Path.join(@root, "docs/case-studies/wd-fa")

  test "machine-readable architecture episode matches executable projection" do
    episode = read_json!("architecture-episode.json")
    projection = Stogaf.demo_projection()

    assert episode["equation"] == projection.equation
    assert episode["current_conformance"] == projection.current_conformance
    assert episode["target_conformance"] == projection.target_conformance
    assert episode["evidence_ceiling"] == projection.evidence_ceiling
    assert episode["authority"] == projection.authority
    assert episode["human_gate"] == projection.human_gate
  end

  test "requirements projection covers all sixteen WD obligations" do
    requirements = read_json!("requirements.json")

    assert length(requirements) == 16
    assert Enum.map(requirements, & &1["id"]) == Enum.map(1..16, &"R-#{pad2(&1)}")
    assert Enum.all?(requirements, &is_binary(&1["court"]))
    assert Enum.all?(requirements, &is_binary(&1["building_block"]))
    assert Enum.all?(requirements, &is_binary(&1["standing"]))
  end

  test "cumulative conformance never promotes production levels" do
    conformance = read_json!("conformance.json")
    by_level = Map.new(conformance, &{&1["level"], &1})

    assert by_level["ST-4"]["standing"] == "ALIVE"
    assert by_level["ST-5"]["standing"] == "PARTIAL_ALIVE"
    assert by_level["ST-6"]["standing"] == "PARTIAL_ALIVE"
    assert by_level["ST-7"]["standing"] == "UNKNOWN"
    assert by_level["ST-8"]["standing"] == "UNKNOWN"
    assert by_level["ST-9"]["standing"] == "UNKNOWN"
  end

  test "every viewpoint is a named projection and not canonical state" do
    viewpoints = read_json!("viewpoints.json")

    assert length(viewpoints) >= 5

    assert Enum.any?(
             viewpoints,
             &(&1["id"] == "fa-engineer" and &1["view"] == "FA Morning Brief")
           )

    assert Enum.any?(
             viewpoints,
             &(&1["id"] == "assessment" and &1["view"] == "WD Case Study 2 Deck")
           )
  end

  test "ADM map includes all phases through architecture change management" do
    phases = read_json!("adm.json") |> Map.new(&{&1["phase"], &1})

    for phase <- ["PRELIMINARY", "A", "B", "C", "D", "E", "F", "G", "H", "REQUIREMENTS"] do
      assert Map.has_key?(phases, phase)
    end

    assert phases["G"]["wd"] =~ "Chicago"
    assert phases["H"]["wd"] =~ "MachineExperience"
  end

  test "semantic pack contains cumulative, authority, view, experience and requirement gates" do
    pack = Path.join(@root, "priv/packs/wd_cs2_pack")

    for gate <- [
          "010_architecture_episode_complete.rq",
          "020_authority_ceiling.rq",
          "030_view_projection.rq",
          "040_machine_experience.rq",
          "050_requirement_traceability.rq"
        ] do
      assert File.regular?(Path.join([pack, "gates", gate]))
    end
  end

  defp read_json!(name) do
    @case_dir
    |> Path.join(name)
    |> File.read!()
    |> Jason.decode!()
  end

  defp pad2(value), do: value |> Integer.to_string() |> String.pad_leading(2, "0")
end
