defmodule Xaas.Ultracode.ProviderMesh.RetryPolicyTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.RetryPolicy

  test "bounds retry",
    do: assert(RetryPolicy.retry?(%RetryPolicy{max_attempts: 2}, 1, :transient))
end
