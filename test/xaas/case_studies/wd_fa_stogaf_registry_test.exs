defmodule Xaas.CaseStudies.WdFaStogafRegistryTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.Stogaf.{Conformance, Metrics, Requirements, Viewpoints, WorkGraph}

  test "all sixteen WD requirement obligations are mapped" do
    assert Requirements.mapped_count() == 16
    assert Enum.map(Requirements.all(), & &1.id) == Enum.map(1..16, &"R-#{pad2(&1)}")
    assert Requirements.standing_counts()["ALIVE_FIXTURE"] >= 10
  end

  test "five stakeholder viewpoints remain projections" do
    assert Viewpoints.count() == 5
    assert Enum.any?(Viewpoints.all(), &(&1.id == "fa-engineer"))
    assert Enum.any?(Viewpoints.all(), &(&1.id == "assessment"))
  end

  test "ST-7 through ST-9 remain explicitly unclaimed" do
    assert Conformance.current() == "ST-4 CONSTRAINED"
    assert Conformance.target() == "ST-6 AUTONOMIC"
    assert Conformance.production_unknown_count() == 3
  end

  test "ST-6 work graph is bounded and acyclic" do
    assert WorkGraph.count() == 10
    assert WorkGraph.entry() == "SJ-011"
    assert WorkGraph.terminal() == "SJ-020"
    assert WorkGraph.acyclic?()
  end

  test "DfCM dashboard measures coverage without inventing business results" do
    summary = Metrics.summary()

    assert summary.requirements_mapped == 16
    assert summary.viewpoints == 5
    assert summary.work_orders == 10
    assert summary.production_levels_unclaimed == 3
    assert summary.known_class_llm_target == "0 general LLM calls"
  end

  defp pad2(value), do: value |> Integer.to_string() |> String.pad_leading(2, "0")
end
