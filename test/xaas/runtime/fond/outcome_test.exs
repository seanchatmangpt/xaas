defmodule Xaas.Runtime.FOND.OutcomeTest do
 use ExUnit.Case, async: true
 test "outcome test" do
  assert Xaas.Runtime.FOND.Outcome.classify({:error,:boom}) == {:fail_edge,:boom}
 end
end
