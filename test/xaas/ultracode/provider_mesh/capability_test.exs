defmodule Xaas.Ultracode.ProviderMesh.CapabilityTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.Capability
  defmodule P do def capabilities, do: [:run] end
  test "matches capability", do: assert Capability.supported?(P,:run)
end
