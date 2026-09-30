defmodule XaaS.Trimtab.RecoveryTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.Recovery

  test "failed edge is excluded only" do
    assert Recovery.exclude([:a, :b, :c], :b) == [:a, :c]
  end
end
