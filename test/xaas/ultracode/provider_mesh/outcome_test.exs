defmodule Xaas.Ultracode.ProviderMesh.OutcomeTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.Outcome

  test "rejects untyped provider result",
    do: assert({:error, {:invalid_provider_outcome, :wat}} = Outcome.normalize(:wat))
end
