defmodule XaaS.Trimtab.StandingTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.Standing
  test "unobserved subject is not alive" do
    refute Standing.alive?(%{observed: false})
  end
end
