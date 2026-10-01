defmodule Xaas.Demo.PradyotSurfaceTest do
  use ExUnit.Case, async: true

  alias Xaas.Demo.PradyotSurface

  @subject "chicago-agentic-payments/demo-v26.10.1"

  test "Chicago and seller projections preserve one exact subject" do
    assert PradyotSurface.chicago().subject == @subject
    assert PradyotSurface.seller().subject == @subject
  end

  test "human projections cannot mint consequential authority" do
    assert PradyotSurface.chicago().authority == :none
    assert PradyotSurface.seller().boundaries.ui_authority == :none
  end

  test "contained evidence stays distinguishable from unavailable live layers" do
    episode = PradyotSurface.chicago()
    assert episode.mode == :contained_demo
    assert episode.freshness == :seeded
    assert Enum.any?(episode.layers, &(&1.state == :unsupported))
    assert Enum.any?(episode.layers, &(&1.state == :partial))
  end

  test "system projection is read only" do
    assert PradyotSurface.system().execution == :read_only
    assert PradyotSurface.system().authority == :none
  end
end
