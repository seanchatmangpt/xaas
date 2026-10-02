defmodule Xaas.Demo.PradyotProjectionContractTest do
  use ExUnit.Case, async: true
  alias Xaas.Demo.PradyotSurface

  @subject "urn:chicago:agentic-payment:purchase-001"

  test "every Chicago layer preserves the exact subject and presentation owns no authority" do
    episode = PradyotSurface.chicago()
    assert episode.subject == @subject
    assert episode.authority == :none
    assert Enum.all?(episode.layers, &(&1.subject == @subject))
  end

  test "unknown after dispatch is an outcome, never standing or replay authority" do
    episode = PradyotSurface.chicago()
    unknown = Enum.find(episode.cases, &(&1.outcome == :unknown_after_dispatch))
    assert episode.standing != :unknown_after_dispatch
    assert unknown.replay == :forbidden
    assert unknown.recovery == :reconcile_original
  end

  test "seller projection cannot mint authority" do
    seller = PradyotSurface.seller()
    assert seller.subject == @subject
    assert seller.boundaries.ui_authority == :none
    assert seller.boundaries.consequential_do == "XaaS/BRCE only"
  end
  test "generic AshSurface projection preserves subject, separation and replay identity" do
    projection = PradyotSurface.ash_surface_projection()

    assert projection.subject == @subject
    assert projection.authority == :none
    assert projection.requirement != projection.capability
    assert projection.planning_episode.do_authority == :none
    assert projection.execution.authority == :none
    assert projection.contracts == [:command_center, :observation, :obligation, :planning_episode, :standing]
    assert PradyotSurface.replay_valid?(projection)
  end

  test "projection replay rejects authority widening and digest mutation" do
    projection = PradyotSurface.ash_surface_projection()

    refute PradyotSurface.replay_valid?(%{projection | authority: :operator})
    refute PradyotSurface.replay_valid?(%{projection | projection_digest: "forged"})
    refute PradyotSurface.replay_valid?(put_in(projection, [:planning_episode, :do_authority], :do))
    refute PradyotSurface.replay_valid?(put_in(projection, [:standing, :state], :unknown_after_dispatch))
  end
end
