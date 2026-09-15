defmodule Xaas.Ultracode.RunStartTest do
  @moduledoc """
  Real Chicago-style proof that ULTRACODE-50 blocker (2) is closed:
  `Xaas.Ultracode.Run.:start` is the ONE real admitted action that
  transitions a fresh Run `:pending -> :running` AND constructs its very
  first Epoch -- no test/caller code creates an Epoch by hand anymore.

  Combined with `Xaas.Ultracode.NextEpoch` (blocker (1), closed in a prior
  cycle), this proves the full unattended path: `Run.:create` -> `Run.
  :start` -> N ticks -> Run reaches `:completed`, with ZERO manual Epoch
  construction anywhere in the flow.
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

  test ":start admits a pending Run, refuses a second call, and constructs the real first Epoch" do
    subject = exact_subject!()

    run =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "run_start_test", max_cycles: 1},
        authorize?: false
      )
      |> Ash.create!()

    assert run.state == :pending
    assert run.cycle == 0

    started_run =
      run
      |> Ash.Changeset.for_update(:start, %{exact_subject: subject}, authorize?: false)
      |> Ash.update!()

    assert started_run.state == :running
    assert started_run.started_at != nil
    assert started_run.cycle == 1

    {:ok, [first_epoch]} =
      Epoch
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.read(authorize?: false)

    assert first_epoch.cycle == 0
    assert first_epoch.state == :expected
    assert first_epoch.exact_subject == subject

    # Real refusal, not a silent no-op, on a second :start call.
    assert {:error, %Ash.Error.Invalid{}} =
             started_run
             |> Ash.Changeset.for_update(:start, %{exact_subject: subject}, authorize?: false)
             |> Ash.update()

    # No second Epoch was constructed by the refused call.
    {:ok, epochs_after_refusal} =
      Epoch
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.read(authorize?: false)

    assert length(epochs_after_refusal) == 1
  end

  test "fully unattended: Run.:create -> Run.:start -> ticks -> Run :completed, zero manual Epoch creation" do
    subject = exact_subject!()

    run =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "run_start_test unattended", max_cycles: 2},
        authorize?: false
      )
      |> Ash.create!()
      |> Ash.Changeset.for_update(:start, %{exact_subject: subject}, authorize?: false)
      |> Ash.update!()

    assert run.state == :running

    # Zero manual Epoch creation from here on -- only real tick calls,
    # same real Reactor the AshOban :tick scheduled action invokes.
    Enum.each(1..4, fn _tick -> {:ok, _} = Reactor.run(Xaas.Ultracode.Reactor) end)

    final_run = Ash.get!(Run, run.id, authorize?: false)
    assert final_run.state == :completed
    assert final_run.standing == :admitted

    {:ok, all_epochs} =
      Epoch
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.read(authorize?: false)

    assert length(all_epochs) == 2
    assert Enum.all?(all_epochs, &(&1.state == :completed))
    assert Enum.all?(all_epochs, &(&1.exact_subject == subject))

    {:ok, receipts} =
      Receipt
      |> Ash.Query.filter(epoch_id in ^Enum.map(all_epochs, & &1.id))
      |> Ash.read(authorize?: false)

    # 2 receipts per epoch (start, complete) x 2 epochs = 4.
    assert length(receipts) == 4
    assert Enum.all?(receipts, &(&1.outcome == :alive))
  end
end
