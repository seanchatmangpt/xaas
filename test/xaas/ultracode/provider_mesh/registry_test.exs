defmodule Xaas.Ultracode.ProviderMesh.RegistryTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.{Registry, Candidate}

  test "registers candidates" do
    {:ok, p} = Registry.start_link(name: :mesh_registry_test)
    :ok = Registry.register(p, Candidate.new("p", __MODULE__))
    assert length(Registry.candidates(p)) == 1
  end
end
