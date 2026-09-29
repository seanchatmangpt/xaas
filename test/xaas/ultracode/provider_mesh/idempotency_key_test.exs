defmodule Xaas.Ultracode.ProviderMesh.IdempotencyKeyTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.IdempotencyKey

  test "stable key",
    do: assert(IdempotencyKey.derive(:run, "s", %{}) == IdempotencyKey.derive(:run, "s", %{}))
end
