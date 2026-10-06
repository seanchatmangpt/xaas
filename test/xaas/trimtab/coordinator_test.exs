defmodule Xaas.Trimtab.CoordinatorTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.Coordinator

  test "coordinator is OTP process" do
    assert {:ok, pid} = Coordinator.start_link(name: :ea80_coord)
    assert Process.alive?(pid)
  end
end
