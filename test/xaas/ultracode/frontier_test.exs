defmodule Xaas.Ultracode.FrontierTest do
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.Frontier

  @moduletag :ultracode

  test "empty frontier is closed and digest-stable across atom/string key order" do
    a = Frontier.empty("test")

    {:ok, b} =
      Frontier.admit(%{
        source: "test",
        unsatisfied_dependencies: 0,
        unpublished_deltas: 0,
        unsettled_epochs: 0,
        active_epochs: 0,
        pending_work: 0,
        metadata: %{}
      })

    assert Frontier.closed?(a)
    assert Frontier.closed?(b)
    assert a["digest"] == b["digest"]
  end

  test "any remaining work keeps the frontier open" do
    {:ok, frontier} =
      Frontier.admit(%{
        "source" => "test",
        "pending_work" => 1,
        "active_epochs" => 0,
        "unsettled_epochs" => 0,
        "unpublished_deltas" => 0,
        "unsatisfied_dependencies" => 0
      })

    refute Frontier.closed?(frontier)
  end

  test "missing or negative closure counts are typed refusals" do
    assert {:error, {:frontier_count, "pending_work", nil}} =
             Frontier.admit(%{"source" => "test"})

    assert {:error, {:frontier_count, "pending_work", -1}} =
             Frontier.admit(%{
               "source" => "test",
               "pending_work" => -1,
               "active_epochs" => 0,
               "unsettled_epochs" => 0,
               "unpublished_deltas" => 0,
               "unsatisfied_dependencies" => 0
             })
  end
end
