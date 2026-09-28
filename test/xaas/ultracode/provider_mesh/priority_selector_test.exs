defmodule Xaas.Ultracode.ProviderMesh.PrioritySelectorTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.{PrioritySelector,Candidate}
  test "lowest priority wins" do [c|_]=PrioritySelector.select([Candidate.new("b",__MODULE__,priority: 2),Candidate.new("a",__MODULE__,priority: 1)]); assert c.id=="a" end
end
