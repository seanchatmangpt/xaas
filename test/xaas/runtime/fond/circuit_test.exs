defmodule Xaas.Runtime.FOND.CircuitTest do
 use ExUnit.Case, async: true
 test "circuit test" do
  c=Xaas.Runtime.FOND.Circuit.new(2)|>Xaas.Runtime.FOND.Circuit.fail(:a)|>Xaas.Runtime.FOND.Circuit.fail(:a); assert Xaas.Runtime.FOND.Circuit.open?(c,:a)
 end
end
