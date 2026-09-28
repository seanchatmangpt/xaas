defmodule Xaas.Runtime.FOND.IdempotencyTest do
  use ExUnit.Case, async: true

  test "idempotency test" do
    assert Xaas.Runtime.FOND.Idempotency.key(:run, %{a: 1}) ==
             Xaas.Runtime.FOND.Idempotency.key(:run, %{a: 1})
  end
end
