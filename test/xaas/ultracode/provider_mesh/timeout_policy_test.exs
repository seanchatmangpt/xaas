defmodule Xaas.Ultracode.ProviderMesh.TimeoutPolicyTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.TimeoutPolicy
  test "future deadline is live" do d=TimeoutPolicy.deadline(%TimeoutPolicy{timeout_ms: 1000}); refute TimeoutPolicy.expired?(d) end
end
