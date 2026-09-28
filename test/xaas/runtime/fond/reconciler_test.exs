defmodule Xaas.Runtime.FOND.ReconcilerTest do
 use ExUnit.Case, async: true
 test "reconciler test" do
  e=Xaas.Runtime.FOND.Edge.new(:a,fn x->x end); g=Xaas.Runtime.FOND.Reconciler.reconcile(Xaas.Runtime.FOND.Graph.new([e]),%{a: :down}); assert Xaas.Runtime.FOND.Graph.reachable(g)==[]
 end
end
