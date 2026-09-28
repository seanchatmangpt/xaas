defmodule Xaas.Runtime.FOND.BackoffTest do
 use ExUnit.Case, async: true
 test "backoff test" do
  assert Xaas.Runtime.FOND.Backoff.delay(0,10,100)==10; assert Xaas.Runtime.FOND.Backoff.delay(5,10,100)==100
 end
end
