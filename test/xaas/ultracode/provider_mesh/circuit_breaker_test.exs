defmodule Xaas.Ultracode.ProviderMesh.CircuitBreakerTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.CircuitBreaker

  test "success closes circuit" do
    s = %CircuitBreaker{opened: %{"p" => 1}, failures: %{"p" => 3}} |> CircuitBreaker.success("p")
    assert CircuitBreaker.available?(s, "p")
  end
end
