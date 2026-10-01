defmodule Xaas.Ultracode.SequencedDrainTest do
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.SequencedDrain

  @ids [
    "jira-xa-3010-pruner-aaaaaa",
    "jira-xa-3007-stale-plan-bbbbbb",
    "jira-xa-3008-vacuity-cccccc",
    "jira-other-0001-zzzzzz"
  ]

  describe "pick/4" do
    test "filters by pattern, sorts, takes batch size" do
      assert SequencedDrain.pick(@ids, "jira-xa-30[0-9][0-9]-", [], 2) ==
               ["jira-xa-3007-stale-plan-bbbbbb", "jira-xa-3008-vacuity-cccccc"]
    end

    test "excludes tickets tried twice" do
      assert SequencedDrain.pick(@ids, "jira-xa-30", ["jira-xa-3007-stale-plan-bbbbbb"], 3) ==
               ["jira-xa-3008-vacuity-cccccc", "jira-xa-3010-pruner-aaaaaa"]
    end

    test "empty when nothing matches" do
      assert SequencedDrain.pick(@ids, "nomatch", [], 3) == []
    end
  end

  test "the batch DAG is sequenced refresh -> select -> wave -> integration -> merge -> verify" do
    steps = Reactor.Info.to_struct!(SequencedDrain).steps |> Enum.map(& &1.name) |> Enum.reverse()
    assert steps == [:refresh, :select, :wave, :integration, :merge, :verify]
  end
end
