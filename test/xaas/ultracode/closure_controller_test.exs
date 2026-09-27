defmodule Xaas.Ultracode.ClosureControllerTest do
  use ExUnit.Case, async: true

  @moduletag :ultracode

  alias Xaas.Ultracode.{ClosureController, Frontier, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "cycle exhaustion with unknown frontier suspends instead of completing" do
    run = running_run!()

    assert {:ok, %{outcome: :suspended, reason: :frontier_unknown}} =
             ClosureController.reconcile_cycle_exhausted(run)

    reloaded = Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false)
    assert reloaded.state == :suspended
    assert reloaded.standing == :unknown
  end

  test "open frontier suspends, resume adds bounded headroom, empty frontier closes" do
    run = running_run!()

    {:ok, %{run: run}} =
      ClosureController.record(run, %{
        "source" => "test",
        "pending_work" => 2,
        "active_epochs" => 0,
        "unsettled_epochs" => 0,
        "unpublished_deltas" => 0,
        "unsatisfied_dependencies" => 0,
        "next_work_item" => %{"id" => "edge-1"}
      })

    assert {:ok, %{outcome: :suspended, frontier_size: 2}} =
             ClosureController.reconcile_cycle_exhausted(run)

    suspended = Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false)
    assert suspended.state == :suspended

    assert {:ok, resumed} = ClosureController.resume(suspended, 3)
    assert resumed.state == :running
    assert resumed.max_cycles >= resumed.cycle + 3

    {:ok, %{run: resumed}} = ClosureController.record(resumed, Frontier.empty("test"))

    assert {:ok, %{outcome: :closed, frontier_size: 0}} =
             ClosureController.reconcile_cycle_exhausted(resumed)

    completed = Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false)
    assert completed.state == :completed
    assert completed.standing == :admitted
  end

  test "corrupt persisted digest cannot prove closure" do
    run = running_run!()

    run =
      run
      |> Ash.Changeset.for_update(
        :record_frontier,
        %{
          frontier: Map.drop(Frontier.empty("test"), ["digest"]),
          frontier_digest: "sha256:" <> String.duplicate("0", 64),
          frontier_size: 0,
          frontier_recorded_at: DateTime.utc_now()
        },
        authorize?: false
      )
      |> Ash.update!()

    assert {:ok, %{outcome: :suspended, reason: :frontier_digest_mismatch}} =
             ClosureController.reconcile_cycle_exhausted(run)

    assert Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false).state == :suspended
  end

  defp running_run! do
    Run
    |> Ash.Changeset.for_create(:create, %{goal: "closure controller test", max_cycles: 1},
      authorize?: false
    )
    |> Ash.create!()
    |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
    |> Ash.update!()
  end
end
