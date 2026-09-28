defmodule Xaas.Runtime.FOND.EdgeTest do
 use ExUnit.Case, async: true
 test "edge test" do
  e=Xaas.Runtime.FOND.Edge.new(:a,fn x->x end,capabilities:[:run]); assert Xaas.Runtime.FOND.Edge.supports?(e,:run)
 end
end
