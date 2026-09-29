defmodule Xaas.Ultracode.ProviderMesh.WeightedSelectorTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.{WeightedSelector, Candidate}

  test "higher weight leads" do
    [c | _] =
      WeightedSelector.select([
        Candidate.new("a", __MODULE__, weight: 1),
        Candidate.new("b", __MODULE__, weight: 9)
      ])

    assert c.id == "b"
  end
end
