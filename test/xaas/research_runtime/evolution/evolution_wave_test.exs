defmodule Xaas.ResearchRuntime.EvolutionWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.SurvivalEvidence
  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_episode_id} = SurvivalEvidence.new([])
    assert {:ok, value} = SurvivalEvidence.new(episode_id: "exact")
    assert {:error, :refused} = SurvivalEvidence.admit(value, fn _ -> false end)
    assert {:ok, admitted} = SurvivalEvidence.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
