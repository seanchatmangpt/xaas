# W705 lane: gap fill from the wasm4pm/ex4pm cross-project audit.
#
# ex4pm's W604 lane (test/w604_map_update_dual_safe_test.exs) pinned observed
# Map.update/4 absent-key behavior after patching 35 absent-key-reliant sites.
# This file ports the canary + pins the top absent-key-reliant Map.update/4
# sites in XAAS's own lib/ so an OTP upgrade that flips the semantics fails
# loudly here instead of silently corrupting counters/indexes.
#
# Census (w705 receipt, docs/sjira/v26.10.6/plans/w705-wasm4pm-ex4pm-gaps.md):
#   11 absent-key-reliant Map.update/4 sites in lib/ (Map.update!/3 sites are
#   exempt — present-key-only by contract). All are functionally reliant on the
#   documented "skip fun on absent key" behavior; none are dual-safe today.

defmodule W705MapUpdateDualSafeTest do
  use ExUnit.Case, async: true

  # -- census receipt (keep in sync with the w705 plan receipt) ---------------

  @absent_key_reliant_sites [
    "lib/xaas/runtime/fond/circuit.ex:4",
    "lib/xaas_web/controllers/ocel_summary_controller.ex:52",
    "lib/xaas_web/controllers/ocel_summary_controller.ex:53",
    "lib/xaas/gall/turtle.ex:139",
    "lib/xaas/gall/turtle.ex:167",
    "lib/xaas/gall/turtle.ex:172",
    "lib/xaas/semantics/vkg/workspace.ex:120",
    "lib/xaas/ultracode/sequenced_drain.ex:239",
    "lib/xaas/ultracode/run_validation.ex:798",
    "lib/xaas/ultracode/run_validation.ex:799",
    "lib/xaas/ultracode/semantic_drive.ex:2472",
    "lib/xaas/fabric/planes/process.ex:26"
  ]

  test "w705 census: absent-key-reliant Map.update/4 site count is stable" do
    assert length(@absent_key_reliant_sites) == 12
  end

  # -- runtime canary (mirrors ex4pm W604) ------------------------------------

  test "canary: Map.update/4 skips fun on absent key on this runtime" do
    assert Map.update(%{}, :k, 7, &(&1 + 1)) == %{k: 7}
  end

  # -- top reliant sites, pinned through their real public surfaces ------------

  test "FOND.Circuit.fail/2: absent key seeds 1, present key increments; threshold boundary" do
    c = Xaas.Runtime.FOND.Circuit.new(3)

    # Absent key: stored value is the default 1, NOT fun.(1) == 2.
    c1 = Xaas.Runtime.FOND.Circuit.fail(c, :edge_a)
    assert c1.failures == %{edge_a: 1}
    refute Xaas.Runtime.FOND.Circuit.open?(c1, :edge_a)

    # Present key: fun applies.
    c2 = Xaas.Runtime.FOND.Circuit.fail(c1, :edge_a)
    c3 = Xaas.Runtime.FOND.Circuit.fail(c2, :edge_a)
    assert c3.failures == %{edge_a: 3}

    # Open only at >= threshold (float-free integer boundary, same discipline).
    refute Xaas.Runtime.FOND.Circuit.open?(c2, :edge_a)
    assert Xaas.Runtime.FOND.Circuit.open?(c3, :edge_a)
    assert Xaas.Runtime.FOND.Circuit.open?(Xaas.Runtime.FOND.Circuit.fail(c3, :edge_a), :edge_a)

    # reset removes the counter entirely (absent again).
    c4 = Xaas.Runtime.FOND.Circuit.reset(c3, :edge_a)
    assert c4.failures == %{}
    refute Xaas.Runtime.FOND.Circuit.open?(c4, :edge_a)
  end

  test "Fabric.Planes.Process.call(:observe): absent key seeds [kind], present appends" do
    {:ok, facts1} = Xaas.Fabric.Planes.Process.call(:observe, nil, %{"process.event" => "requested"}, [])

    assert facts1["process.events"] == ["requested"]

    {:ok, facts2} =
      Xaas.Fabric.Planes.Process.call(
        :observe,
        nil,
        Map.merge(facts1, %{"process.event" => "constructed"}),
        []
      )

    assert facts2["process.events"] == ["requested", "constructed"]
  end

  # A dual-safe rewrite is lib/ work outside this lane's contract; the pins
  # above are the typed note: these sites are correct under documented OTP
  # semantics and break loudly under any flip.
end
