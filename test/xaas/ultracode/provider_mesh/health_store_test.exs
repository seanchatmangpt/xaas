defmodule Xaas.Ultracode.ProviderMesh.HealthStoreTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.{HealthStore, HealthSnapshot}

  test "stores observation" do
    {:ok, p} = HealthStore.start_link(name: :mesh_health_test)
    :ok = HealthStore.put(p, HealthSnapshot.healthy("p"))
    assert HealthStore.get(p, "p").status == :healthy
  end
end
