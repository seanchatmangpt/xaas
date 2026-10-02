defmodule Xaas.Demo.PradyotSemanticSeparationTest do
  use ExUnit.Case, async: true
  alias Xaas.Demo.PradyotSurface

  test "requirement capability plan realization execution evidence and standing remain distinct" do
    chicago = PradyotSurface.chicago()
    ids = Enum.map(chicago.layers, & &1.id)
    assert :sjira in ids
    assert :sa2a in ids
    assert :ash_pplan in ids
    assert :realization in ids
    assert :xaas in ids
    assert :ex4pm in ids
    assert :affidavit in ids
    assert chicago.standing == :partial
  end

  test "planning visibility does not imply DO authority" do
    chicago = PradyotSurface.chicago()
    assert chicago.authority == :none
    assert Enum.find(chicago.layers, &(&1.id == :ash_pplan)).subject == chicago.subject
    assert Enum.find(chicago.layers, &(&1.id == :realization)).subject == chicago.subject
  end

  test "unsupported and partial evidence are preserved rather than promoted" do
    layers = PradyotSurface.chicago().layers
    assert Enum.find(layers, &(&1.id == :beam4pm)).state == :unsupported
    assert Enum.find(layers, &(&1.id == :affidavit)).state == :partial
    refute Enum.any?(layers, &(&1.state == :alive))
  end

  test "runtime projection is observation-only" do
    system = PradyotSurface.system()
    assert system.authority == :none
    assert system.execution.mode == :read_only
    assert system.standing == :partial
  end

  test "refused cases carry no DO while admitted case remains explicitly bounded" do
    cases = PradyotSurface.chicago().cases
    refused = Enum.filter(cases, &(&1.outcome == :refused))
    assert refused != []
    assert Enum.all?(refused, &(&1.do == :none))
    assert Enum.find(cases, &(&1.outcome == :admitted)).do == :bounded
  end
end
