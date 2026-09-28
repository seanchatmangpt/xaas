defmodule Xaas.Ultracode.ProviderMesh.ContractTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.Contract
  test "requires identity and module", do: assert {:error,:missing_provider_fields}=Contract.validate(%{id:"x"})
end
