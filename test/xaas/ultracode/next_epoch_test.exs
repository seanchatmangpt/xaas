defmodule Xaas.Ultracode.NextEpochTest do
  @moduledoc """
  Real Chicago-style proof of the ULTRACODE-50 milestone's core falsifier
  for blocker (1): "2 real full unattended epochs" -- a Run is created and
  given exactly one starting Epoch, then `Xaas.Ultracode.Reactor` (the
  ENTIRE real body of the AshOban `:tick` scheduled action) is invoked
  repeatedly with ZERO manual Epoch creation between calls. Both epoch
  cycles complete, both produce real receipts, and the Run itself reaches
  `:completed` at `max_cycles` -- all driven purely by tick calls.

  Real `Ecto.Adapters.SQL.Sandbox`-backed Postgres, real Ash actions, real
  `Reactor.run/2` execution of both `Xaas.Ultracode.Reactor` (the tick
  body) and, transitively, `Xaas.Ultracode.EpochReactor` (the per-epoch
  DAG). No mocks/stubs.

  Blocker (2) (nothing transitions a fresh Run from `:pending` to
  `:running`, and nothing constructs a Run's very first Epoch) is
  explicitly still open -- this test bridges it by hand in setup (creating
  the Run already `:running` with its first Epoch and bumping
  `Run.cycle` to match, exactly the bookkeeping a future admitted
  "start Run" action would perform) and calls that out rather than
  silently working around it. Only the tick-driven advance-to-next-epoch
  path (blocker (1)) is under test here.
  """
  use ExUnit.Case, async: true

  require Ash.Query

  @moduletag :ultracode

  alias Xaas.Ultracode.{Epoch, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp exact_subject! do
    {sha, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: File.cwd!())
    String.trim(sha)
  end

  test "Run with max_cycles=2 completes 2 epochs across 4 ticks with zero manual epoch creation" do
    subject = exact_subject!()

    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "next_epoch_test 2-epoch unattended run", max_cycles: 2},
        authorize?: false
      )
      |> Ash.create!()
      |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
      |> Ash.update!()

    assert run.state == :running
    assert run.cycle == 0

    first_epoch =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{run_id: run.id, cycle: 0, exact_subject: subject, state: :expected, expected_at: DateTime.utc_now()},
        authorize?: false
      )
      |> Ash.create!()

    # Bridges still-open blocker (2): a future admitted "start Run" action
    # would create this first Epoch AND advance Run.cycle in one real
    # transition. Done by hand here, explicitly, not inside NextEpoch.
    run =
      run
      |> Ash.Changeset.for_update(:advance_cycle, %{}, authorize?: false)
      |> Ash.update!()

    assert run.cycle == 1

    # --- Tick 1: epoch 0 :expected -> :running. No manual intervention. ---
    {:ok, _tick1} = Reactor.run(Xaas.Ultracode.Reactor)
    epoch0_after_tick1 = Ash.get!(Epoch, first_epoch.id, authorize?: false)
    assert epoch0_after_tick1.state == :running

    # --- Tick 2: epoch 0 :running -> :completed, AND (same tick's
    # :advance_next_epochs step) epoch 1 constructed as :expected. This is
    # the real assertion that blocker (1) is closed: nothing but the tick
    # itself produced epoch cycle=1. ---
    {:ok, _tick2} = Reactor.run(Xaas.Ultracode.Reactor)
    epoch0_after_tick2 = Ash.get!(Epoch, first_epoch.id, authorize?: false)
    assert epoch0_after_tick2.state == :completed

    {:ok, [epoch1]} =
      Epoch
      |> Ash.Query.filter(run_id == ^run.id and cycle == 1)
      |> Ash.read(authorize?: false)

    assert epoch1.state == :expected
    assert epoch1.exact_subject == subject

    run_after_tick2 = Ash.get!(Run, run.id, authorize?: false)
    assert run_after_tick2.cycle == 2
    assert run_after_tick2.state == :running

    # --- Tick 3: epoch 1 :expected -> :running. Still zero manual epoch
    # creation. ---
    {:ok, _tick3} = Reactor.run(Xaas.Ultracode.Reactor)
    epoch1_after_tick3 = Ash.get!(Epoch, epoch1.id, authorize?: false)
    assert epoch1_after_tick3.state == :running

    # --- Tick 4: epoch 1 :running -> :completed, AND (same tick) the Run
    # itself reaches max_cycles=2, so :advance_next_epochs transitions the
    # Run to :completed rather than constructing a third epoch. ---
    {:ok, _tick4} = Reactor.run(Xaas.Ultracode.Reactor)
    epoch1_after_tick4 = Ash.get!(Epoch, epoch1.id, authorize?: false)
    assert epoch1_after_tick4.state == :completed

    final_run = Ash.get!(Run, run.id, authorize?: false)
    assert final_run.state == :completed
    assert final_run.standing == :admitted

    # No third epoch was ever constructed.
    {:ok, all_epochs} =
      Epoch
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.read(authorize?: false)

    assert length(all_epochs) == 2

    # ReceiptCoverage for this run's two EpochReactor-mediated epochs: 2
    # receipts per epoch (start, complete) = 4 real persisted receipts,
    # each bound to its epoch's exact_subject.
    {:ok, receipts} =
      Receipt
      |> Ash.Query.filter(epoch_id in [^first_epoch.id, ^epoch1.id])
      |> Ash.read(authorize?: false)

    assert length(receipts) == 4
    assert Enum.all?(receipts, &(&1.subject == subject))
    assert Enum.all?(receipts, &(&1.outcome == :alive))
  end
end
