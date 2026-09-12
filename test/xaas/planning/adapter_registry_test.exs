defmodule Xaas.Planning.AdapterRegistryTest do
  use ExUnit.Case, async: true

  alias Xaas.Planning.{AdapterRegistry, Formalism}

  test "the real registry is honestly empty in this slice -- no formalism is capable" do
    assert AdapterRegistry.all() == %{}
    assert Enum.all?(Formalism.all(), &(not AdapterRegistry.capable?(&1)))
  end

  test "adapter_for/1 returns a typed error for every formalism" do
    for formalism <- Formalism.all() do
      assert {:error, :no_adapter_registered} = AdapterRegistry.adapter_for(formalism)
    end
  end
end
