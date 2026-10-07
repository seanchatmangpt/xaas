defmodule Xaas.Graphlaw.LimitGateTest do
  @moduledoc """
  SPEC-10 (W731-GAP-2) court — lane W976 design-wave 5.

  Chicago-style: real EngineLimit rows on real sandboxed Postgres, real
  `Catalog.ingest/1` against the real graphlaw registry, real bridge
  calls. No mocks.

  Falsifier (from the W731 receipt, verbatim intent): an EngineLimit row is
  no longer a projection only — a `max_json_depth = 64` limit against a
  real depth-65 payload must REFUSE (typed, naming the engine's
  `refusal_name`), not persist happily into the engine.

  Mutation rationale: reverting the gate wiring in
  `Xaas.Bridges.Graphlaw.assess/2` (deleting the
  `LimitGate.enforce/2` call, restoring the pre-SPEC-10 direct engine
  dispatch) flips "gate refuses a depth-65 claim at the bridge seam" and
  "registry seam surfaces engine limits" RED — the depth-65 claim would
  sail past the gate to the engine, and no registry function would read an
  EngineLimit row. Deleting `Registry.engine_limits/0` flips the registry
  seam court RED. The fail-open rescue arm (unreadable limit store
  admits) in `LimitGate.enforce/2` is not directly killable by a
  green-path court without inducing a read failure; disclosed as accepted
  residual.
  """

  use ExUnit.Case, async: true

  alias Xaas.Bridges.Registry
  alias Xaas.Graphlaw.Catalog
  alias Xaas.Graphlaw.EngineLimit
  alias Xaas.Graphlaw.LimitGate

  @dead_server :l7_graphlaw_host_never_started
  @subject Xaas.Bridges.subject()

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_limit(attrs) do
    EngineLimit
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!()
  end

  defp abi_depth_limit(value, refusal_name \\ "state_quads") do
    create_limit(%{
      name: "max_json_depth",
      value: value,
      scope: "abi",
      source: "src/abi.rs",
      unit: "count",
      refusal_name: refusal_name
    })
  end

  ## (a) the gate itself: real rows, real measurements

  test "SPEC-10 falsifier: depth-65 measured against max_json_depth=64 refuses, naming refusal_name" do
    abi_depth_limit(64)

    assert {:refused, info} = LimitGate.enforce("abi", %{"max_json_depth" => 65})
    assert info.code == :limit_exceeded
    assert info.limit == "max_json_depth"
    assert info.limit_value == 64
    assert info.actual == 65
    assert info.refusal_name == "state_quads"
    assert info.message =~ "max_json_depth"
  end

  test "depth equal to the limit admits; below admits" do
    abi_depth_limit(64)

    assert :ok = LimitGate.enforce("abi", %{"max_json_depth" => 64})
    assert :ok = LimitGate.enforce("abi", %{"max_json_depth" => 63})
  end

  test "no recorded limit for a measured name admits (projection stays a projection)" do
    abi_depth_limit(64)

    assert :ok = LimitGate.enforce("abi", %{"unrelated_limit" => 10_000_000})
  end

  test "no limit rows at all admits" do
    assert :ok = LimitGate.enforce("abi", %{"max_json_depth" => 10_000_000})
  end

  test "json_depth/1 measures real nesting; nest/1 builds the adversarial payload" do
    assert LimitGate.json_depth(%{}) == 1
    assert LimitGate.json_depth(%{"a" => 1}) == 2
    assert LimitGate.json_depth(%{"a" => %{"b" => %{"c" => 1}}}) == 4
    assert LimitGate.json_depth(%{"a" => [%{"b" => 1}]}) == 4
    # nest(n) is depth n+1: nest(64) is the depth-65 adversarial payload.
    assert LimitGate.json_depth(LimitGate.nest(64)) == 65
  end

  ## (b) the bridge seam: Xaas.Bridges.Graphlaw.assess/2 gates before the engine

  test "gate refuses a depth-65 claim at the bridge seam, before the engine" do
    abi_depth_limit(64)

    assert {:refused, refusal} =
             Xaas.Bridges.Graphlaw.assess(LimitGate.nest(64),
               server: @dead_server,
               subject: @subject
             )

    assert refusal.code == :limit_exceeded
    assert refusal.class == :refused_admission
    assert refusal.limit == "max_json_depth"
    assert refusal.refusal_name == "state_quads"
    # The engine was never reached: not the host-layer refusal.
    refute refusal.code == :host_not_started
  end

  test "gate passes a within-limit claim through to the engine dispatch" do
    abi_depth_limit(64)

    claim = Map.merge(LimitGate.nest(63), %{"amount" => 10, "limit" => 5})
    assert LimitGate.json_depth(claim) == 64

    # Dead server: the ONLY refusal available is the host layer's, proving
    # the gate admitted the claim and the engine call was attempted.
    assert {:refused, refusal} =
             Xaas.Bridges.Graphlaw.assess(claim, server: @dead_server, subject: @subject)

    assert refusal.code == :host_not_started
  end

  ## (c) the registry seam: Registry reads real EngineLimit rows

  test "registry engine_limits/0 returns real abi-scope rows from the real registry" do
    abi_depth_limit(64)

    limits = Registry.engine_limits()

    assert Enum.any?(limits, &(&1.name == "max_json_depth" and &1.value == 64))
  end

  test "ingesting the real graphlaw registry feeds both seams (limits visible through the registry)" do
    path = Catalog.default_registry_path()
    {:ok, _counts} = Catalog.ingest(path)

    limits = Registry.engine_limits()
    assert Enum.any?(limits, &(&1.name == "max_json_depth"))

    # The gate consumes the same real rows.
    assert {:refused, info} = LimitGate.enforce("abi", %{"max_json_depth" => 65})
    assert info.limit_value == 64
  end

  ## (d) determinism of the depth measure

  test "depth measure is deterministic on the same claim" do
    claim = LimitGate.nest(64)
    assert LimitGate.json_depth(claim) == LimitGate.json_depth(claim)
  end
end
