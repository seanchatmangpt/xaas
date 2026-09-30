defmodule XaaS.Trimtab.CoordinatorTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.Coordinator

  test "coordinator is OTP process" do
    assert {:ok, pid} = Coordinator.start_link([])
    assert Process.alive?(pid)
  end
end
