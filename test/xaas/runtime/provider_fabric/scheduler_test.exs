defmodule Xaas.Runtime.ProviderFabric.SchedulerTest do
  use ExUnit.Case, async: true
  test "scheduler runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Scheduler)
  end
end
