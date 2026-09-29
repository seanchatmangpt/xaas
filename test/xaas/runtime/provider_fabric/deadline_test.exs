defmodule Xaas.Runtime.ProviderFabric.DeadlineTest do
  use ExUnit.Case, async: true

  test "deadline runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Deadline)
  end
end
