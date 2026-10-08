defmodule Xaas.ApplicationSupervisionCourtW984LjTest do
  @moduledoc """
  W984lj — supervision-tree contract court for `Xaas.Application`.

  Witnesses the REAL started test-env tree via `Supervisor.which_children/1`
  (every DataCase test boots the app, so `Xaas.Supervisor` is live here —
  no start_supervised!, no doubles).

  Observed OTP behavior this court pins: on this OTP release,
  `Supervisor.which_children/1` reports children in REVERSE start order
  (last-declared child first), so declaration order is recovered with
  `Enum.reverse/1` before ordering asserts.

  Mutations this court kills, per test:

  - removing a child line from `children` in application.ex -> set/length assert
  - reordering children (e.g. swapping Repo and Oban) -> declaration-order assert
  - flipping the sa2a_bridge_children gate -> gate-consistency assert
  - changing `strategy: :one_for_one` -> strategy assert
  - rewiring Oban off Xaas.Repo or out of :manual testing mode -> Oban wiring assert
  """
  use ExUnit.Case, async: false

  @sup Xaas.Supervisor

  test "top-level supervisor is alive under the documented name" do
    # Mutation: renaming Xaas.Supervisor in application.ex fails this.
    assert Process.whereis(@sup) |> is_pid()
    assert Process.alive?(Process.whereis(@sup))
  end

  test "children set matches application.ex source (17 unconditional + conditional bridge)" do
    # Mutation: deleting any child line from `children` fails this.
    expected = MapSet.new([
      XaasWeb.Endpoint,
      Xaas.PromEx,
      DNSCluster,
      XaasWeb.Telemetry,
      Xaas.LegacyRepo,
      Xaas.Repo,
      Oban,
      Xaas.Vault,
      Xaas.Hammer,
      Phoenix.PubSub.Supervisor,
      Xaas.Finch,
      Xaas.Ultracode.TaskSupervisor,
      Xaas.Ultracode.ProviderRecovery,
      XaasWeb.A2A.NextReadUserAgent,
      XaasWeb.A2A.NextReadAshAgent,
      XaasWeb.A2A.ZoeEventSimulationAgent,
      AshPPlan.Reactor.Durable.Store.Ets
    ])

    ids = child_ids() |> MapSet.new()
    assert MapSet.size(ids) == MapSet.size(expected)
    assert ids == expected

    # Conditional tail: the ONLY source-conditional child is Xaas.Sa2a.Bridge
    # (present or absent as a whole). Mutation: adding a new unconditional
    # child without updating this court fails here; hardcoding the bridge
    # in/out against available?/0 fails the gate test below.
    extra =
      child_ids()
      |> MapSet.new()
      |> MapSet.difference(expected)
      |> MapSet.to_list()

    assert extra in [[], [Xaas.Sa2a.Bridge]]
  end

  test "declaration order: Repo (and LegacyRepo) before Oban (restart-order dependency)" do
    # which_children reports reverse start order on this OTP; reversing
    # recovers source declaration order. Mutation: swapping Xaas.Repo and
    # {Oban, ...} in application.ex fails this.
    decl = Enum.reverse(child_ids())

    repo_i = Enum.find_index(decl, &(&1 == Xaas.Repo))
    oban_i = Enum.find_index(decl, &(&1 == Oban))
    legacy_i = Enum.find_index(decl, &(&1 == Xaas.LegacyRepo))
    endpoint_i = Enum.find_index(decl, &(&1 == XaasWeb.Endpoint))

    assert is_integer(repo_i) and is_integer(oban_i)
    assert legacy_i < repo_i
    assert repo_i < oban_i
    # Endpoint declared first per source.
    assert endpoint_i == 0
  end

  test "conditional sa2a bridge gate: tree and available?/0 agree" do
    # Source gate: sa2a_bridge_children = if Xaas.Sa2a.Bridge.available?()
    # (System.find_executable("autofde")). Mutation: hardcoding
    # [Xaas.Sa2a.Bridge] unconditionally fails the absent branch on any host
    # without autofde on PATH; hardcoding [] fails the present branch.
    present? = Xaas.Sa2a.Bridge.available?()
    in_tree? = Xaas.Sa2a.Bridge in child_ids()
    assert present? == in_tree?
  end

  test "worker/supervisor child types match the real tree" do
    by_id = which_children() |> Map.new(fn {id, _, type, _} -> {id, type} end)

    # Mutation: changing a child into a different child shape (e.g. a module
    # child that becomes a supervisor via {mod, arg}) flips its type here.
    for sup_id <- [
          XaasWeb.Endpoint,
          Xaas.PromEx,
          XaasWeb.Telemetry,
          Xaas.LegacyRepo,
          Xaas.Repo,
          Oban,
          Phoenix.PubSub.Supervisor,
          Xaas.Ultracode.TaskSupervisor
        ] do
      assert by_id[sup_id] == :supervisor, "#{inspect(sup_id)} must be :supervisor"
    end

    for worker_id <- [
          DNSCluster,
          Xaas.Vault,
          Xaas.Hammer,
          Xaas.Finch,
          Xaas.Ultracode.ProviderRecovery,
          XaasWeb.A2A.NextReadUserAgent,
          XaasWeb.A2A.NextReadAshAgent,
          XaasWeb.A2A.ZoeEventSimulationAgent,
          AshPPlan.Reactor.Durable.Store.Ets
        ] do
      assert by_id[worker_id] == :worker, "#{inspect(worker_id)} must be :worker"
    end
  end

  test "restart strategy is one_for_one (re-read from the live supervisor)" do
    # Mutation: changing opts strategy in application.ex fails this.
    # :sys.get_state on an OTP 28 supervisor is {:state, name, strategy, children}.
    state = :sys.get_state(@sup)
    assert elem(state, 2) == :one_for_one
  end

  test "Oban child is wired to Xaas.Repo in :manual testing mode (test-env contract)" do
    # The ULTRACODE-50 fix routes the base Oban config through AshOban.config/2
    # in the child spec; in the TEST env the running Oban is in :manual testing
    # mode with plugins/queues stripped by the test config.
    # Mutation: rewiring {Oban, ...} to a different repo fails this; removing
    # the Oban child entirely fails every Oban assert in this file.
    conf = Oban.config(Oban)
    assert %Oban.Config{} = conf
    assert conf.repo == Xaas.Repo
    assert conf.testing == :manual
  end

  defp which_children do
    Supervisor.which_children(@sup)
  end

  defp child_ids do
    Enum.map(which_children(), fn {id, _, _, _} -> id end)
  end
end
