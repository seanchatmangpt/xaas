defmodule Xaas.Runtime.FOND.GraphTest do
 use ExUnit.Case, async: true
 test "graph test" do
  g=Xaas.Runtime.FOND.Graph.new(); assert Xaas.Runtime.FOND.Graph.reachable(g)==[]
 end
end
