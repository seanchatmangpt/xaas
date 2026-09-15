defmodule Xaas.Ultracode.EpochReactorTest do
  @moduledoc """
  Real Chicago-style end-to-end test of the Ultracode Run/Epoch/Receipt
  control plane: real Ecto.Adapters.SQL.Sandbox-backed Postgres (Xaas.Repo),
  real Ash resources, real `Xaas.Ultracode.MissedEpochs` state transition,
  real `Xaas.Ultracode.EpochReactor` Reactor DAG execution, real persisted
  `Receipt`. No mocks/stubs of any collaborator.

  Observed subject: the real current git SHA of `/Users/sac/xaas` itself
  (via `System.cmd("git", ["rev-parse", "HEAD"])`), chosen over a fixture
  string because this task explicitly offered either and a real repo SHA is
  strictly more real evidence than an arbitrary fixture -- the whole point
  of `exact_subject` per the ontology formalization is that it is the real
  thing being run against.
  """
  use ExUnit.Case, async: true

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

  test "full Run -> tick(:mark_missed) -> Epoch -> EpochReactor -> Receipt -> Run lifecycle" do
    subject = exact_subject!()

    # 1) Real durable Run.
    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "ultracode epoch_reactor_test lifecycle",
          max_cycles: 2,
          # Small real threshold so a real past-due `expected_at` (set
          # below) is genuinely stale by the time MissedEpochs runs --
          # not a mocked clock, a real elapsed-time comparison.
          epoch_timeout_seconds: 1
        },
        authorize?: false
      )
      |> Ash.create!()

    run =
      run
      |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
      |> Ash.update!()

    assert run.state == :running

    # 2) Materialize expected epoch state: a first, deliberately
    # already-stale Epoch (cycle 0) whose expected_at is already more than
    # epoch_timeout_seconds in the past.
    stale_expected_at = DateTime.add(DateTime.utc_now(), -60, :second)

    stale_epoch =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: subject,
          state: :expected,
          expected_at: stale_expected_at
        },
        authorize?: false
      )
      |> Ash.create!()

    assert stale_epoch.state == :expected

    # 3) Invoke the real code path the AshOban `:tick` scheduled action
    # triggers directly (Xaas.Ultracode.MissedEpochs.advance_all/0 -- the
    # entire body of the Reactor step the `:tick` generic action runs).
    [summary] = MissedEpochs.advance_all()
    assert summary.run_id == run.id
    assert stale_epoch.id in summary.missed

    reloaded_stale_epoch = Ash.get!(Epoch, stale_epoch.id, authorize?: false)
    assert reloaded_stale_epoch.state == :missed

    # 4) A second, real durable Epoch (cycle 1) -- the one this test drives
    # through the real EpochReactor DAG.
    active_epoch =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 1,
          exact_subject: subject,
          state: :expected,
          expected_at: DateTime.utc_now()
        },
        authorize?: false
      )
      |> Ash.create!()

    assert active_epoch.state == :expected

    # 5) Execute the real EpochReactor: Observe -> Admit -> Plan ->
    # Construct -> Verify -> Receipt. First pass: :expected -> :running
    # (real CONSTRUCT via Epoch's admitted `:start` action).
    {:ok, first_result} = Reactor.run(Xaas.Ultracode.EpochReactor, %{epoch_id: active_epoch.id})

    assert first_result.epoch_id == active_epoch.id
    assert first_result.action_taken == :start
    # 6/8) Real verification outcome + a real persisted Receipt id.
    assert first_result.outcome == :alive
    assert is_binary(first_result.receipt_id)

    after_start = Ash.get!(Epoch, active_epoch.id, authorize?: false)
    assert after_start.state == :running

    first_receipt = Ash.get!(Receipt, first_result.receipt_id, authorize?: false)
    assert first_receipt.epoch_id == active_epoch.id
    assert first_receipt.subject == subject
    assert first_receipt.outcome == :alive
    assert first_receipt.evidence["expected_state"] == "running"
    assert first_receipt.evidence["observed_state"] == "running"

    # 7) Second pass over the same Epoch: real CONSTRUCT :running ->
    # :completed, exercising the invariant `CompletedEpoch => Receipt`
    # (this second real Receipt is what satisfies it).
    {:ok, second_result} = Reactor.run(Xaas.Ultracode.EpochReactor, %{epoch_id: active_epoch.id})

    assert second_result.action_taken == :complete
    assert second_result.outcome == :alive

    completed_epoch = Ash.get!(Epoch, active_epoch.id, authorize?: false)
    assert completed_epoch.state == :completed

    second_receipt = Ash.get!(Receipt, second_result.receipt_id, authorize?: false)
    assert second_receipt.epoch_id == active_epoch.id
    assert second_receipt.outcome == :alive
    assert second_receipt.evidence["observed_state"] == "completed"

    # Real distinct receipts persisted -- Receipt.subject == Epoch.subject
    # invariant, checked directly.
    assert second_receipt.id != first_receipt.id
    assert second_receipt.subject == active_epoch.exact_subject

    # 10) Advance real durable Run state, reflecting the completed cycle.
    advanced_run =
      run
      |> Ash.Changeset.for_update(:mark_completed_epoch, %{last_completed_epoch_at: DateTime.utc_now()}, authorize?: false)
      |> Ash.update!()
      |> Ash.Changeset.for_update(:advance_cycle, %{}, authorize?: false)
      |> Ash.update!()

    assert advanced_run.cycle == run.cycle + 1
    assert advanced_run.last_completed_epoch_at != nil

    final_run =
      advanced_run
      |> Ash.Changeset.for_update(:transition_state, %{state: :completed, standing: :admitted}, authorize?: false)
      |> Ash.update!()

    assert final_run.state == :completed
    assert final_run.standing == :admitted
  end
end
