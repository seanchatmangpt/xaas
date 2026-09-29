defmodule Xaas.Ultracode.ProviderMesh.RouteDecisionTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.RouteDecision
  test "empty candidates exhaust route", do: assert(RouteDecision.exhausted?(%RouteDecision{}))
end
