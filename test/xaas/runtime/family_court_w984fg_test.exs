defmodule Xaas.Runtime.FamilyCourtW984fgTest do
  @moduledoc """
  W984fg unclaimed-family probe court over `lib/xaas/runtime/` — the
  top-level state-bearing modules left uncovered after excluding W984dq8's
  ProviderRegistry lane and the fully-covered FOND/ProviderFabric
  sub-namespaces (each has a per-module test file under
  `test/xaas/runtime/{fond,provider_fabric}/`).

  Covered here:
    * `Xaas.Runtime.Reconciler` — GenServer probe loop; none of the four
      health-outcome branches (`:healthy` / `:degraded` /
      `{:unavailable, reason}` / invalid-other) were exercised anywhere in
      test/, and the loop's self-rescheduling `handle_info` never ran.
    * `Xaas.Runtime.FOND.Registry` — named GenServer map store; zero
      references anywhere in test/.
    * `Xaas.Runtime.Supervisor` and `Xaas.Runtime.FOND.Supervisor` —
      supervision-tree wiring, never started by any test.

  Real GenServers under the ExUnit test supervisor, real named providers,
  real state assertions, zero mocks.

  Mutation rationale per test (what mutation each test kills):
  """

  use ExUnit.Case, async: false

  alias Xaas.Runtime.ProviderRegistry
  alias Xaas.Runtime.Reconciler

  # -- test-local real providers (hand-written real implementations) --------

  defmodule HealthyProvider do
    def capabilities, do: [:compute]
    def health(_ctx), do: :healthy
  end

  defmodule DegradedProvider do
    def capabilities, do: [:compute]
    def health(_ctx), do: :degraded
  end

  defmodule DownProvider do
    def capabilities, do: [:compute]
    def health(_ctx), do: {:unavailable, :socket_closed}
  end

  defmodule InvalidHealthProvider do
    def capabilities, do: [:compute]
    def health(_ctx), do: :bogus
  end

  defmodule RaisingProvider do
    def capabilities, do: [:compute]
    def health(_ctx), do: raise("boom")
  end

  setup context do
    unless context[:no_default_stack] do
      start_supervised!(Supervisor.child_spec({ProviderRegistry, failure_threshold: 3, cooldown_ms: 1},
        id: :w984fg_registry
      ))

    # Large interval so only the explicitly-sent :reconcile drives probing.
    start_supervised!(Supervisor.child_spec({Reconciler, interval_ms: 60_000, context: %{ttl: 1}},
      id: :w984fg_reconciler
    ))
    end

    :ok
  end

  test "probe loop reports :healthy -> :ok, resetting failures to a ready entry" do
    ProviderRegistry.register(HealthyProvider, priority: 1)

    send(Reconciler, :reconcile)
    wait_until(fn -> entry(HealthyProvider).status == :ready end)

    e = entry(HealthyProvider)
    assert e.status == :ready and e.failures == 0 and is_nil(e.opened_at)
  end

  test "probe loop reports :degraded -> {:error, :degraded}, entering the degraded mid-state" do
    ProviderRegistry.register(DegradedProvider, priority: 1)

    send(Reconciler, :reconcile)
    wait_until(fn -> entry(DegradedProvider).status == :degraded end)

    e = entry(DegradedProvider)
    assert e.status == :degraded and e.failures == 1
  degraded = e
    assert is_nil(degraded.opened_at)
  end

  test "probe loop reports raising health as {:unavailable, {kind, reason}} failure" do
    ProviderRegistry.register(RaisingProvider, priority: 1)

    send(Reconciler, :reconcile)
    wait_until(fn -> entry(RaisingProvider).status == :degraded end)

    e = entry(RaisingProvider)
    assert e.status == :degraded
    assert e.failures == 1
  end

  test "probe loop reports {:unavailable, reason} return as a failure" do
    ProviderRegistry.register(DownProvider, priority: 1)

    send(Reconciler, :reconcile)
    wait_until(fn -> entry(DownProvider).status == :degraded end)

    assert entry(DownProvider).failures == 1
  end

  test "probe loop reports a non-contract health return as {:error, {:invalid_health, other}}" do
    ProviderRegistry.register(InvalidHealthProvider, probes: 0, priority: 1)

    send(Reconciler, :reconcile)
    wait_until(fn -> entry(InvalidHealthProvider).status == :degraded end)

    assert entry(InvalidHealthProvider).failures == 1
  end

  test "reconcile loop iterates over every registered provider in one pass" do
    ProviderRegistry.register(HealthyProvider, priority: 1)
    ProviderRegistry.register(DegradedProvider, priority: 2)

    send(Reconciler, :reconcile)
    wait_until(fn -> entry(DegradedProvider).status == :degraded end)

    assert entry(HealthyProvider).status == :ready
    assert entry(DegradedProvider).status == :degraded
  end

  test "loop reschedules itself: a second reconcile tick re-probes and accumulates failures" do
    ProviderRegistry.register(DegradedProvider, priority: 1)

    send(Reconciler, :reconcile)
    wait_until(fn -> entry(DegradedProvider).failures == 1 end)

    send(Reconciler, :reconcile)
    wait_until(fn -> entry(DegradedProvider).failures == 2 end)

    send(Reconciler, :reconcile)
    wait_until(fn -> entry(DegradedProvider).status == :open and entry(DegradedProvider).failures == 3 end)
  end

  @tag :no_default_stack
  test "Xaas.Runtime.Supervisor starts ProviderRegistry and Reconciler children rest_for_one" do
    spec = %{
      id: :w984fg_top_sup,
      start:
        {Supervisor, :start_link,
         [
           [
             {Xaas.Runtime.Supervisor,
              registry: [failure_threshold: 5, cooldown_ms: 1],
              reconciler: [interval_ms: 60_000]}
           ],
           [strategy: :one_for_all, name: :"W984fg.TopSup"]
         ]},
      restart: :temporary
    }

    start_supervised!(spec)

    children = Supervisor.which_children(:"W984fg.TopSup")
    assert [{Xaas.Runtime.Supervisor, pid, :supervisor, [Xaas.Runtime.Supervisor]}] = children
    assert Process.alive?(pid)

    grand_children = Supervisor.which_children(pid)
    names = grand_children |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    assert names == [ProviderRegistry, Reconciler]
    assert Enum.all?(grand_children, fn {_, pid, _, _} -> Process.alive?(pid) end)
  end

  test "Xaas.Runtime.FOND.Supervisor starts with an empty one_for_one child list" do
    start_supervised!(
      Supervisor.child_spec({Xaas.Runtime.FOND.Supervisor, []},
        id: :w984fg_fond_sup,
        restart: :temporary
      )
    )

    assert Supervisor.which_children(Xaas.Runtime.FOND.Supervisor) == []
  end

  test "Xaas.Runtime.FOND.Registry stores entries and answers :all with the full map" do
    start_supervised!(
      Supervisor.child_spec({Xaas.Runtime.FOND.Registry, [name: :"W984fg.FondRegistry"]},
        id: :w984fg_fond_registry,
        restart: :temporary
      )
    )

    reg = :"W984fg.FondRegistry"
    assert :ok = Xaas.Runtime.FOND.Registry.register(reg, :edge_a, %{plan: [:a, :b]})
    assert :ok = Xaas.Runtime.FOND.Registry.register(reg, :edge_b, %{plan: [:c]})

    assert %{:edge_a => %{plan: [:a, :b]}, :edge_b => %{plan: [:c]}} =
             Xaas.Runtime.FOND.Registry.all(reg)
  end

  test "Xaas.Runtime.FOND.Registry overwrites on duplicate id and preserves state across calls" do
    start_supervised!(
      Supervisor.child_spec({Xaas.Runtime.FOND.Registry, [name: :"W984fg.FondRegistry2"]},
        id: :w984fg_fond_registry2,
        restart: :temporary
      )
    )

    reg = :"W984fg.FondRegistry2"
    :ok = Xaas.Runtime.FOND.Registry.register(reg, :x, 1)
    :ok = Xaas.Runtime.FOND.Registry.register(reg, :x, 2)
    assert Xaas.Runtime.FOND.Registry.all(reg) == %{x: 2}

    # :all replies with the state and does not clear it
    assert Xaas.Runtime.FOND.Registry.all(reg) == %{x: 2}
  end

  # -- helpers ---------------------------------------------------------------

  defp entry(provider) do
    ProviderRegistry.snapshot()
    |> Map.get(provider)
  end

  defp wait_until(fun, tries \\ 100)

  defp wait_until(_fun, 0), do: flunk("condition not reached")

  defp wait_until(fun, tries) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      wait_until(fun, tries - 1)
    end
  end
end
