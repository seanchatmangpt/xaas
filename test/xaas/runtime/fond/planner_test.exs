defmodule Xaas.Runtime.FOND.PlannerTest do
 use ExUnit.Case, async: true
 test "planner test" do
  e=Xaas.Runtime.FOND.Edge.new(:a,fn x->x end,capabilities: [:run]); assert Xaas.Runtime.FOND.Planner.plan(Xaas.Runtime.FOND.Graph.new([e]),[:run])==[run: [:a]]
 end
end
