defmodule Xaas.Ultracode.MissedEpochReceiptTest do
  @moduledoc """
  Real Chicago-style proof that the ULTRACODE-50 receipt-coverage gap is
  closed: `Xaas.Ultracode.MissedEpochs.advance_run/1`'s `:expected ->
  :missed` transition now seals a real `Receipt`, so `ReceiptCoverage`
  for a run's consequential transitions is `3/3`, not the `2/3` the
  original milestone swarm measured.
  """
  use ExUnit.Case, async: true

  require Ash.Query

  @moduletag :ultracode

  alias Xaas.Ultracode.{Epoch, MissedEpochs, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp exact_subject! do
    {sha, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: File.cwd!())
    String.trim(sha)
  end

  test "a missed epoch seals a real Receipt with outcome :blocked, closing ReceiptCoverage to 1" do
    subject = exact_subject!()

    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "missed_epoch_receipt_test", max_cycles: 1, epoch_timeout_seconds: 1},
        authorize?: false
      )
      |> Ash.create!()
      |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
      |> Ash.update!()

    stale_epoch =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: subject,
          state: :expected,
          expected_at: DateTime.add(DateTime.utc_now(), -60, :second)
        },
        authorize?: false
      )
      |> Ash.create!()

    summary = MissedEpochs.advance_run(run)
    assert summary.run_id == run.id
    assert stale_epoch.id in summary.missed

    reloaded_epoch = Ash.get!(Epoch, stale_epoch.id, action: :read_unscoped, authorize?: false)
    assert reloaded_epoch.state == :missed

    # The consequential transition (:expected -> :missed) now has a real
    # persisted Receipt, closing the previously-measured gap.
    {:ok, receipts} =
      Receipt
      |> Ash.Query.filter(epoch_id == ^stale_epoch.id)
      |> Ash.read(authorize?: false)

    assert length(receipts) == 1
    [receipt] = receipts

    assert receipt.subject == subject
    assert receipt.outcome == :blocked
    assert receipt.evidence["expected_state"] == "completed"
    assert receipt.evidence["observed_state"] == "missed"
    assert receipt.evidence["epoch_timeout_seconds"] == 1
  end

  test "advance_all/0 seals one Receipt per missed epoch across multiple runs" do
    subject = exact_subject!()

    make_stale_run = fn ->
      run =
        Run
        |> Ash.Changeset.for_create(
          :create,
          %{
            goal: "missed_epoch_receipt_test advance_all",
            max_cycles: 1,
            epoch_timeout_seconds: 1
          },
          authorize?: false
        )
        |> Ash.create!()
        |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
        |> Ash.update!()

      epoch =
        Epoch
        |> Ash.Changeset.for_create(
          :create,
          %{
            run_id: run.id,
            cycle: 0,
            exact_subject: subject,
            state: :expected,
            expected_at: DateTime.add(DateTime.utc_now(), -60, :second)
          },
          authorize?: false
        )
        |> Ash.create!()

      {run, epoch}
    end

    {run_a, epoch_a} = make_stale_run.()
    {run_b, epoch_b} = make_stale_run.()

    summaries = MissedEpochs.advance_all()
    run_ids = Enum.map(summaries, & &1.run_id)
    assert run_a.id in run_ids
    assert run_b.id in run_ids

    {:ok, receipts} =
      Receipt
      |> Ash.Query.filter(epoch_id in [^epoch_a.id, ^epoch_b.id])
      |> Ash.read(authorize?: false)

    assert length(receipts) == 2
    assert Enum.all?(receipts, &(&1.outcome == :blocked))
  end
end
