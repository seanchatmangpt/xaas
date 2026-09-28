defmodule Xaas.Runtime.FOND.HealthTest do
 use ExUnit.Case, async: true
 test "health test" do
  assert Xaas.Runtime.FOND.Health.normalize({:error,:x})==:down; assert Xaas.Runtime.FOND.Health.normalize(:ok)==:healthy
 end
end
