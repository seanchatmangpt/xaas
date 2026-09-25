defmodule Xaas.CaseStudies.WdFaStogafSchemasTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)
  @schema_dir Path.join(@root, "docs/case-studies/wd-fa/schema")
  @fixture_dir Path.join(@root, "priv/packs/wd_cs2_pack/fixtures")

  test "all interchange schemas are valid JSON documents with declared schema identity" do
    for file <- Path.wildcard(Path.join(@schema_dir, "*.schema.json")) do
      decoded = file |> File.read!() |> Jason.decode!()
      assert decoded["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    end
  end

  test "case fixtures carry source-bound observed evidence" do
    for name <- ["known_firmware.json", "partial_firmware.json", "novel_x.json"] do
      fixture = read_fixture!(name)

      assert is_binary(fixture["case_id"])
      assert is_list(fixture["evidence"])

      Enum.each(fixture["evidence"], fn evidence ->
        assert evidence["source_ref"] =~ "fixture://wd/"
        assert evidence["provenance_state"] == "OBSERVED"
        assert evidence["subject"] == fixture["case_id"]
      end)
    end
  end

  test "MachineExperience fixture is applicability and replay bound" do
    experience = read_fixture!("machine_experience_novel_x.json")

    assert experience["id"] == "MX-NOVEL-X-001"
    assert experience["verified_disposition"] == "MODE-X-NOVEL"
    assert experience["evidence_ceiling"] == "REPO_LOCAL_FIXTURE"
    assert is_binary(experience["receipt_identity"])
    assert is_binary(experience["replay_identity"])
    assert map_size(experience["applicability"]) > 0
  end

  test "negative controls cover confidence, evidence, similarity, receipt and authority failures" do
    controls = read_fixture!("negative-controls.json")
    ids = MapSet.new(controls, & &1["id"])

    for id <- ["NC-01", "NC-02", "NC-03", "NC-04", "NC-05", "NC-06"] do
      assert MapSet.member?(ids, id)
    end
  end

  defp read_fixture!(name) do
    @fixture_dir
    |> Path.join(name)
    |> File.read!()
    |> Jason.decode!()
  end
end
