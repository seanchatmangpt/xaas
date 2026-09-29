defmodule Xaas.Ultracode.ProviderMesh.FailureTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.Failure

  test "classifies transient failures" do
    assert Failure.class(:timeout) == :transient
    assert Failure.class(:boom) == :terminal
  end
end
