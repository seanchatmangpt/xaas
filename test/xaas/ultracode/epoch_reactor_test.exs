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

    reloaded_stale_epoch =
      Ash.get!(Epoch, stale_epoch.id, action: :read_unscoped, authorize?: false)

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

    after_start = Ash.get!(Epoch, active_epoch.id, action: :read_unscoped, authorize?: false)
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

    completed_epoch = Ash.get!(Epoch, active_epoch.id, action: :read_unscoped, authorize?: false)
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
      |> Ash.Changeset.for_update(
        :mark_completed_epoch,
        %{last_completed_epoch_at: DateTime.utc_now()},
        authorize?: false
      )
      |> Ash.update!()
      |> Ash.Changeset.for_update(:advance_cycle, %{}, authorize?: false)
      |> Ash.update!()

    assert advanced_run.cycle == run.cycle + 1
    assert advanced_run.last_completed_epoch_at != nil

    final_run =
      advanced_run
      |> Ash.Changeset.for_update(:transition_state, %{state: :completed, standing: :admitted},
        authorize?: false
      )
      |> Ash.update!()

    assert final_run.state == :completed
    assert final_run.standing == :admitted
  end

  describe ":construct step's real undo/3" do
    # Real falsifier for ULTRACODE-50's ERRC RAISE item: before this,
    # EpochReactor's :construct step performed a real, irreversible
    # mutation with no compensate/undo -- if a downstream step failed
    # after :construct already committed, the Epoch was left permanently
    # transitioned with no receipt at all, violating this subsystem's own
    # `CompletedEpoch => Receipt` invariant.
    #
    # Forcing a genuine downstream Ash failure (without mocking anything)
    # to trigger Reactor's OWN undo dispatch proved impractical without
    # modifying production code just for the test -- so this exercises
    # the real, compiled `undo/3` callback directly via Reactor's own
    # step introspection (`Multigraph.vertices/1` + `Reactor.Step.undo/4`,
    # the exact API Reactor itself uses internally to invoke undo). Every
    # collaborator inside undo is still real: real Ash.update, real
    # Ash.create, real Postgres via Ecto.Adapters.SQL.Sandbox -- nothing
    # mocked, only the *trigger* (a genuinely failed downstream step) is
    # bypassed in favor of calling the real callback directly.
    setup do
      subject = exact_subject!()

      run =
        Run
        |> Ash.Changeset.for_create(:create, %{goal: "undo falsifier", max_cycles: 2},
          authorize?: false
        )
        |> Ash.create!()
        |> Ash.Changeset.for_update(:transition_state, %{state: :running})
        |> Ash.update!()

      construct_step =
        Xaas.Ultracode.EpochReactor.reactor().plan
        |> Multigraph.vertices()
        |> Enum.find(&(&1.name == :construct))

      assert Reactor.Step.can?(construct_step, :undo)

      %{run: run, subject: subject, construct_step: construct_step}
    end

    test "action_taken == :start -- undo marks the Epoch :failed and seals a build_broken Receipt",
         %{run: run, subject: subject, construct_step: construct_step} do
      epoch =
        Epoch
        |> Ash.Changeset.for_create(:create, %{
          run_id: run.id,
          cycle: 0,
          exact_subject: subject,
          state: :expected,
          expected_at: DateTime.utc_now()
        })
        |> Ash.create!()

      # Real Construct-equivalent mutation: :expected -> :running, the
      # exact transition the real :construct step's run/2 performs for
      # action_taken == :start.
      constructed_epoch =
        epoch
        |> Ash.Changeset.for_update(:start, %{})
        |> Ash.update!()

      assert constructed_epoch.state == :running

      value = %{epoch: constructed_epoch, action_taken: :start}

      assert :ok = Reactor.Step.undo(construct_step, value, %{}, %{})

      reloaded = Ash.get!(Epoch, epoch.id, action: :read_unscoped)
      assert reloaded.state == :failed

      [receipt] =
        Receipt
        |> Ash.Query.filter(epoch_id == ^epoch.id)
        |> Ash.read!(authorize?: false)

      assert receipt.outcome == :build_broken
      assert receipt.subject == subject
      assert receipt.evidence["action_taken"] == "start"
    end

    test "action_taken == :complete -- undo leaves the real :completed state and seals a build_broken Receipt",
         %{run: run, subject: subject, construct_step: construct_step} do
      epoch =
        Epoch
        |> Ash.Changeset.for_create(:create, %{
          run_id: run.id,
          cycle: 0,
          exact_subject: subject,
          state: :running,
          expected_at: DateTime.utc_now()
        })
        |> Ash.create!()

      # Real Construct-equivalent mutation: :running -> :completed, the
      # exact transition the real :construct step's run/2 performs for
      # action_taken == :complete.
      constructed_epoch =
        epoch
        |> Ash.Changeset.for_update(:complete, %{})
        |> Ash.update!()

      assert constructed_epoch.state == :completed

      value = %{epoch: constructed_epoch, action_taken: :complete}

      assert :ok = Reactor.Step.undo(construct_step, value, %{}, %{})

      # The real transition genuinely succeeded -- undo does NOT
      # force-revert a real :completed epoch to :failed (that would
      # misrepresent a real success as a failure, and Epoch's own
      # EpochTransitionAllowed validation refuses :mark_failed from
      # :completed anyway).
      reloaded = Ash.get!(Epoch, epoch.id, action: :read_unscoped)
      assert reloaded.state == :completed

      [receipt] =
        Receipt
        |> Ash.Query.filter(epoch_id == ^epoch.id)
        |> Ash.read!(authorize?: false)

      assert receipt.outcome == :build_broken
      assert receipt.subject == subject
      assert receipt.evidence["action_taken"] == "complete"
    end

    test "action_taken == :start against a CONCURRENTLY-changed row refuses cleanly instead of clobbering it",
         %{run: run, subject: subject, construct_step: construct_step} do
      epoch =
        Epoch
        |> Ash.Changeset.for_create(:create, %{
          run_id: run.id,
          cycle: 0,
          exact_subject: subject,
          state: :expected,
          expected_at: DateTime.utc_now()
        })
        |> Ash.create!()

      # Real Construct-equivalent mutation: :expected -> :running -- the
      # exact transition the real :construct step's run/2 performs for
      # action_taken == :start. `stale_constructed_epoch` is the
      # in-memory struct :construct would have handed undo, captured
      # BEFORE the concurrent change below -- exactly the falsifier this
      # fix targets: a snapshot that goes stale by the time undo actually
      # runs.
      stale_constructed_epoch =
        epoch
        |> Ash.Changeset.for_update(:start, %{})
        |> Ash.update!()

      assert stale_constructed_epoch.state == :running

      # Real concurrent change: a SECOND, independent Ash update against
      # the same row -- not a mock, not a stub, a real transition to
      # :completed via the real admitted :complete action (as if
      # Lease.close/4 had closed this same epoch out-of-band while the
      # original EpochReactor invocation was still in flight downstream
      # of :construct). The in-memory `stale_constructed_epoch` above
      # still reads :running -- it was captured before this update ran.
      concurrently_completed_epoch =
        stale_constructed_epoch
        |> Ash.Changeset.for_update(:complete, %{})
        |> Ash.update!()

      assert concurrently_completed_epoch.state == :completed

      value = %{epoch: stale_constructed_epoch, action_taken: :start}

      # undo must not crash and must not silently no-op -- it returns
      # :ok, exactly like the other undo branches, but the crucial
      # falsifier is what it did NOT do: see the reload below.
      assert :ok = Reactor.Step.undo(construct_step, value, %{}, %{})

      # THE FALSIFIER: the real row must still be :completed. Before the
      # fix, undo applied :mark_failed straight to the stale
      # `stale_constructed_epoch` struct (state: :running in memory), and
      # `EpochTransitionAllowed`'s `from: [:expected, :running]` check
      # reads the CHANGESET's data -- the stale struct, not a fresh read
      # -- so it would have passed and silently clobbered this real
      # :completed row to :failed.
      reloaded = Ash.get!(Epoch, epoch.id, action: :read_unscoped)
      assert reloaded.state == :completed

      # Not a silent no-op either: a real, typed :refused Receipt lands
      # naming exactly what was observed.
      [refusal_receipt] =
        Receipt
        |> Ash.Query.filter(epoch_id == ^epoch.id and outcome == :refused)
        |> Ash.read!(authorize?: false)

      assert refusal_receipt.subject == subject
      assert refusal_receipt.evidence["undo_refused_reason"] == "concurrent_state_change"
      assert refusal_receipt.evidence["expected_state"] == "running"
      assert refusal_receipt.evidence["observed_state"] == "completed"
      assert refusal_receipt.evidence["action_taken"] == "start"
    end
  end
end
