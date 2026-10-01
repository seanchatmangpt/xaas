defmodule Xaas.Demo.PradyotSurfaceTest do
  use ExUnit.Case, async: true

  alias Xaas.Demo.PradyotSurface

  @subject "urn:chicago:agentic-payment:purchase-001"

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

  test "typed refusals never gain DO and unknown dispatch never blind replays" do
    cases = PradyotSurface.chicago().cases
    assert Enum.all?(Enum.filter(cases, &(&1.outcome == :refused)), &(&1.do == :none))
    unknown = Enum.find(cases, &(&1.outcome == :unknown_after_dispatch))
    assert unknown.recovery == :reconcile_original
    assert unknown.replay == :forbidden
  end

  test "system projection is read only" do
    assert PradyotSurface.system().execution.mode == :read_only
    assert PradyotSurface.system().execution.unknown_after_dispatch == :reconcile_never_replay
    assert PradyotSurface.system().authority == :none
  end
end
