defmodule Xaas.CaseStudies.WdFaStandardCatalogTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.{LearningLoop, StandardCatalog}

  test "verified MachineExperience creates an explicit standard-work version delta" do
    baseline = StandardCatalog.baseline()
    assert {:ok, %{experience: experience}} = LearningLoop.verify_novel_fixture()
    assert {:ok, changed} = StandardCatalog.admit_experience(experience)

    assert baseline.version == "CS2-V1"
    assert changed.previous_version == "CS2-V1"
    assert changed.version == "CS2-V2"
    assert Enum.any?(changed.modes, &(&1.id == "MODE-X-NOVEL"))
    assert changed.admitted_experience == "MX-NOVEL-X-001"
    assert changed.receipt_digest == experience.receipt_digest
  end

  test "standard change refuses evidence ceiling drift" do
    assert {:ok, %{experience: experience}} = LearningLoop.verify_novel_fixture()
    bad = %{experience | evidence_ceiling: "EXTERNAL"}

    assert {:error, :evidence_ceiling_mismatch} = StandardCatalog.admit_experience(bad)
  end
end
