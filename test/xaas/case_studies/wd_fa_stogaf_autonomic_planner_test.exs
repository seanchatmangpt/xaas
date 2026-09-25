defmodule Xaas.CaseStudies.WdFaStogafAutonomicPlannerTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.Stogaf.AutonomicPlanner

  test "empty evidence state deterministically selects the entry work order" do
    standings = AutonomicPlanner.initial_standings()

    assert {:work, work} = AutonomicPlanner.next(standings)
    assert work.id == "SJ-011"
    assert work.dependencies == []
    assert work.runtime_intelligence == "NONE"
    assert work.authority == "SELECT_CONSTRUCT_ONLY"
  end

  test "admitted dependencies advance selection without human reconstruction" do
    standings =
      AutonomicPlanner.initial_standings()
      |> Map.put("SJ-011", "ALIVE")
      |> Map.put("SJ-012", "ALIVE")
      |> Map.put("SJ-013", "ALIVE")
      |> Map.put("SJ-014", "ALIVE")
      |> Map.put("SJ-015", "ALIVE")
      |> Map.put("SJ-016", "ALIVE")

    assert {:work, work} = AutonomicPlanner.next(standings)
    assert work.id == "SJ-017"
    assert Enum.sort(work.dependencies) == ["SJ-013", "SJ-014", "SJ-016"]
  end

  test "complete graph has no further work" do
    standings =
      AutonomicPlanner.initial_standings()
      |> Map.new(fn {id, _standing} -> {id, "ALIVE"} end)

    assert :complete = AutonomicPlanner.next(standings)
  end

  test "missing admitted dependency blocks downstream promotion" do
    standings =
      AutonomicPlanner.initial_standings()
      |> Map.put("SJ-011", "ALIVE")
      |> Map.put("SJ-012", "ALIVE")
      |> Map.put("SJ-013", "BLOCKED")

    assert {:work, work} = AutonomicPlanner.next(standings)
    assert work.id == "SJ-013"
  end
end
