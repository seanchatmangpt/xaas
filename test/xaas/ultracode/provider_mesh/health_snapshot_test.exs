defmodule Xaas.Ultracode.ProviderMesh.HealthSnapshotTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.HealthSnapshot
  test "typed health", do: assert HealthSnapshot.healthy("p").status==:healthy
end
