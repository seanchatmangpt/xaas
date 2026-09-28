defmodule Xaas.Runtime.FOND.ExecutorTest do
 use ExUnit.Case, async: true
 test "executor test" do
  e=Xaas.Runtime.FOND.Edge.new(:a,fn _->{:ok,:done} end,capabilities:[:run]); assert {:ok,:done,:a,_}=Xaas.Runtime.FOND.Executor.run(Xaas.Runtime.FOND.Graph.new([e]),:run,:x)
 end
end
