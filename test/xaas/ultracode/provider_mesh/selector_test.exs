defmodule Xaas.Ultracode.ProviderMesh.SelectorTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.{Selector,Candidate}
  defmodule P do def capabilities, do: [:run] end
  test "filters unsupported providers", do: assert length(Selector.for_capability([Candidate.new("p",P)],:run))==1
end
