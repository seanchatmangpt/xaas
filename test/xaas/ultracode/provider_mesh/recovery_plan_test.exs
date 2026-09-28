defmodule Xaas.Ultracode.ProviderMesh.RecoveryPlanTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.{RecoveryPlan,Candidate}
  test "failure removes only edge" do p=RecoveryPlan.new(:run,[Candidate.new("a",__MODULE__),Candidate.new("b",__MODULE__)]) |> RecoveryPlan.fail("a",:timeout); assert p.remaining==["b"] end
end
