defmodule Xaas.ResearchRuntime.FederationWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.SourceBinding
  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_source_sha} = SourceBinding.new([])
    assert {:ok, value} = SourceBinding.new(source_sha: "exact")
    assert {:error, :refused} = SourceBinding.admit(value, fn _ -> false end)
    assert {:ok, admitted} = SourceBinding.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
