defmodule Xaas.Runtime.FOND.SelectorTest do
 use ExUnit.Case, async: true
 test "selector test" do
  e=Xaas.Runtime.FOND.Edge.new(:a,fn x->x end,capabilities:[:run]); g=Xaas.Runtime.FOND.Graph.new([e]); assert {:ok,^e}=Xaas.Runtime.FOND.Selector.next(g,:run)
 end
end
