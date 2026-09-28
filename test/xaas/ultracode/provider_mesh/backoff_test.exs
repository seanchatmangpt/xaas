defmodule Xaas.Ultracode.ProviderMesh.BackoffTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.Backoff
  test "bounded exponential delay" do assert Backoff.delay(1,100)==100; assert Backoff.delay(9,100,500)==500 end
end
