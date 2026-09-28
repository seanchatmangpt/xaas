defmodule Xaas.Runtime.FOND.PolicyTest do
 use ExUnit.Case, async: true
 test "policy test" do
  p=Xaas.Runtime.FOND.Policy.new(max_attempts: 2); assert Xaas.Runtime.FOND.Policy.allow_attempt?(p,1); refute Xaas.Runtime.FOND.Policy.allow_attempt?(p,2)
 end
end
