defmodule Xaas.Ultracode.ProviderMesh.CandidateTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.Candidate

  test "defaults are deterministic" do
    c = Candidate.new("p", __MODULE__)
    assert c.priority == 100
    assert c.weight == 1
  end
end
