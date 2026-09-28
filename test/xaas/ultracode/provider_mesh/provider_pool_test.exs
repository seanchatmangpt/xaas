defmodule Xaas.Ultracode.ProviderMesh.ProviderPoolTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.{ProviderPool,Candidate}
  test "removes unhealthy" do cs=[Candidate.new("a",__MODULE__),Candidate.new("b",__MODULE__)]; assert Enum.map(ProviderPool.available(cs,%{"a"=>%{status: :unhealthy}}),& &1.id)==["b"] end
end
