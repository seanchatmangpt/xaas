defmodule Xaas.Runtime.FOND.RuntimeTest do
 use ExUnit.Case, async: true
 test "runtime test" do
  e=Xaas.Runtime.FOND.Edge.new(:a,fn _->{:ok,42} end,capabilities: [:run]); assert {:ok,42,:a,_}=Xaas.Runtime.FOND.Runtime.dispatch(Xaas.Runtime.FOND.Runtime.new([e]),:run,:x)
 end
end
