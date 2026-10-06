defmodule Xaas.Trimtab.StandingTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.Standing

  test "unobserved subject is not alive" do
    assert Standing.derive([], 1) == {:partial, %{observed: 0, required: 1}}
    assert Standing.derive([%{id: 1}, %{id: 2}], 2) == {:alive, %{observed: 2, required: 2}}
  end
end
