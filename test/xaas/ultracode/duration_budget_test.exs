defmodule Xaas.Ultracode.DurationBudgetTest do
  @moduledoc """
  Qualification of the duration-budget law (`Xaas.Ultracode.DurationBudget`)
  -- the operator's 8-hour standing-wave order as executable law:

    * pure law: `deadline/1` == the DB-computed `Run.budget_deadline_at`;
      the boundary is inclusive (at start + budget the run is exhausted --
      "continuous waves for EXACTLY 8 hours");
    * the boundary: at start + 8h + epsilon there is NO new dispatch, the
      drain is observed, the run reaches terminal `:completed`, and the
      final receipt reports waves run, epochs terminal-counted, and
      duration actual vs budget;
    * resume semantics: a stopped run with remaining budget resumes and
      the budget is wall-clock from `started_at`, never reset;
    * claim lane: `Lease.claim_next/3` never hands out an exhausted run's
      epochs (other runs still claimable);
    * epoch-dispatch lane: `NextEpoch` constructs no new epoch past the
      budget (even with `max_cycles` headroom) and completes the run once
      drained; a stale in-flight epoch is reaped by the existing
      `MissedEpochs` rule before completion;
    * drain guard: a LIVE lease is finished, not abandoned -- the run
      stays `:running` (draining) until it is terminal;
    * capacity governor: `Autonomic.dispatch_bounded/3` (the production
      gate the standing wave's workers are admitted through) never has
      more than `capacity` workers in flight at any instant -- including
      when the in-flight workers are REAL lease holders
      (`Lease.claim_next/3`).

  Clock discipline (evidence law): no test sleeps real hours. The clock
  is injected through the law's own seam (`:xaas, :ultracode_clock`) and
  fast-forwarded in steps; sleeps are milliseconds. The capacity tests
  are an enumerated deterministic grid (capacities x item counts), not a
  random property generator, deliberately: the repo's `:property` tag is
  excluded from the default `mix test` loop, and an invariant this
  load-bearing belongs in the fast, always-run suite.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Ultracode.{
    Autonomic,
    DurationBudget,
    Epoch,
    Lease,
    MissedEpochs,
    NextEpoch,
    Receipt,
    Run
  }

  require Ash.Query

  # Fixed law clock origin -- every test starts the injected clock here.
  @t0 ~U[2026-09-19T08:00:00.000000Z]
  @budget 28_800

  setup do
    # This repo's DataCase convention for Xaas.Repo-backed Ultracode
    # tests (see autonomic_test/lease_verifier_test): explicit sandbox
    # checkout, shared so the capacity governor's Task workers (real
    # Lease.claim_next callers) can use the same sandboxed connection.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    {:ok, _} = Agent.start_link(fn -> @t0 end, name: __MODULE__.Clock)
    Application.put_env(:xaas, :ultracode_clock, {__MODULE__, :clock})

    on_exit(fn ->
      Application.delete_env(:xaas, :ultracode_clock)
      Application.delete_env(:xaas, :ultracode_wave_rearm)
    end)

    :ok
  end

  # The injected clock -- read by DurationBudget.now/0 through
  # `:xaas, :ultracode_clock`.
  def clock, do: Agent.get(__MODULE__.Clock, & &1)

  def fast_forward(seconds) do
    Agent.update(__MODULE__.Clock, &DateTime.add(&1, seconds, :second))
  end

  # ------------------------------------------------------------------
  # Pure law
  # ------------------------------------------------------------------

  describe "pure law" do
    test "deadline is started_at + budget, identical to the DB calculation" do
      session = begin_session!()

      assert DurationBudget.deadline(session) == DateTime.add(@t0, @budget, :second)

      loaded = Ash.get!(Run, session.id, action: :read_unscoped, load: [:budget_deadline_at])

      assert DateTime.compare(loaded.budget_deadline_at, DurationBudget.deadline(session)) == :eq
    end

    test "a never-started run has no budget in force" do
      run = create_run!(%{})

      assert DurationBudget.deadline(run) == nil
      assert DurationBudget.remaining_seconds(run, clock()) == nil
      assert DurationBudget.exhausted?(run, clock()) == false
      assert DurationBudget.gate(run, clock()) == :allow
    end

    test "the boundary is inclusive: exactly 8 hours is exhausted, one second before is not" do
      session = begin_session!()

      fast_forward(@budget - 1)
      assert DurationBudget.gate(session, clock()) == :allow

      fast_forward(1)
      assert {:refuse, :budget_exhausted, details} = DurationBudget.gate(session, clock())
      assert details.overrun_seconds == 0
      assert details.budget_seconds == @budget

      fast_forward(1)
      assert {:refuse, :budget_exhausted, details} = DurationBudget.gate(session, clock())
      assert details.overrun_seconds == 1
    end
  end

  # ------------------------------------------------------------------
  # The boundary: no dispatch + drain + terminal + receipt
  # ------------------------------------------------------------------

  describe "budget boundary" do
    test "start + 8h + epsilon: no new dispatch, drain observed, terminal completed, receipt" do
      session = begin_session!()
      {:ok, session} = DurationBudget.record_wave(session)
      {:ok, session} = DurationBudget.record_wave(session)

      # Epsilon past the boundary: dispatch is refused, with the overrun
      # on the record.
      fast_forward(@budget + 1)

      assert {:refuse, :budget_exhausted, %{overrun_seconds: 1}} =
               DurationBudget.gate(session, clock())

      # Drain + terminal transition + final receipt.
      assert {:ok, %{run: completed, receipt: receipt}} =
               DurationBudget.drain_and_complete(session, now: clock())

      assert completed.state == :completed
      assert completed.waves_run == 2

      assert receipt["schema"] == "xaas.run-duration-budget-receipt/1"
      assert receipt["run_id"] == completed.id
      assert receipt["waves_run"] == 2
      assert receipt["budget_seconds"] == @budget
      assert receipt["duration_actual_seconds"] == @budget + 1
      assert receipt["within_budget"] == false
      assert receipt["human_inputs"] == 0

      assert receipt["started_at"] == DateTime.to_iso8601(@t0)
      assert receipt["deadline_at"] == DateTime.to_iso8601(DateTime.add(@t0, @budget, :second))

      # Epochs terminal-counted: a session owns none, so "nothing in
      # flight" is checkable, not narrated.
      assert receipt["epochs"] == %{
               "expected" => 0,
               "running" => 0,
               "completed" => 0,
               "missed" => 0,
               "failed" => 0
             }

      # The terminal state is durable (re-read from the DB).
      assert Ash.get!(Run, completed.id, action: :read_unscoped).state == :completed
    end
  end

  # ------------------------------------------------------------------
  # Resume semantics
  # ------------------------------------------------------------------

  describe "resume semantics" do
    test "a stopped run resumes with remaining budget counted from started_at, never reset" do
      {:ok, _session, :begun} = DurationBudget.find_or_begin_wave_session(now: clock())

      # Stopped for 2 hours (no fires). Resume: same session, phase :resumed.
      fast_forward(2 * 3600)
      assert {:ok, session, :resumed} = DurationBudget.find_or_begin_wave_session(now: clock())
      assert DurationBudget.remaining_seconds(session, clock()) == 6 * 3600

      # Stopped for another 3 hours. Still the same started_at.
      fast_forward(3 * 3600)
      assert {:ok, session, :resumed} = DurationBudget.find_or_begin_wave_session(now: clock())
      assert session.started_at == @t0
      assert DurationBudget.remaining_seconds(session, clock()) == 3 * 3600

      {:ok, _} = DurationBudget.record_wave(session)

      # Resume never extends the budget: the ORIGINAL boundary holds.
      fast_forward(3 * 3600)
      assert {:refuse, :budget_exhausted, _} = DurationBudget.gate(session, clock())

      reread = Ash.get!(Run, session.id, action: :read_unscoped)
      assert reread.started_at == @t0
      assert reread.waves_run == 1
    end

    test "after completion the loop stays stopped; re-arm is an explicit opt-in" do
      session = begin_session!()
      fast_forward(@budget + 1)
      assert {:ok, %{run: completed}} = DurationBudget.drain_and_complete(session, now: clock())

      # No running session and a terminal one on record: refuse a new one.
      # (Identity compared: the returned session is a fresh load of the
      # same row, and struct-instance equality across two loads is not
      # the fact under test -- WHICH session and its terminality are.)
      assert {:refuse, :standing_wave_completed, returned} =
               DurationBudget.find_or_begin_wave_session(now: clock())

      assert returned.id == completed.id
      assert returned.state == :completed

      # Opt-in re-arm begins a FRESH session (new clock origin).
      Application.put_env(:xaas, :ultracode_wave_rearm, true)
      fast_forward(3600)

      assert {:ok, fresh, :begun} = DurationBudget.find_or_begin_wave_session(now: clock())
      assert fresh.id != completed.id
      assert fresh.started_at == DateTime.add(@t0, @budget + 1 + 3600, :second)
    end
  end

  # ------------------------------------------------------------------
  # Claim lane: exhausted runs' epochs are not ready work
  # ------------------------------------------------------------------

  describe "Lease.claim_next budget gate" do
    test "an exhausted run's epochs are never claimed; other runs still are" do
      provider = "budget-claim-test"

      # Run A: 1-hour budget. Run B: full 8-hour budget. Same provider,
      # so they compete in one claim pool. `:start` creates each first
      # epoch in `:expected`; the claim pool is `:running` epochs, so
      # both are taken through the real epoch `:start` transition.
      a = started_run!(%{provider: provider, duration_budget_seconds: 3600})
      b = started_run!(%{provider: provider})
      epoch_to_running!(a)
      epoch_to_running!(b)

      # At t0 both are claimable: A's epoch is oldest (inserted first).
      assert {:ok, %{run_id: run_a_id}, token_a, _run} = Lease.claim_next(provider)
      assert run_a_id == a.id
      assert {:ok, _, _} = Lease.refuse(token_a, :test)

      assert {:ok, %{run_id: run_b_id}, token_b, _run} = Lease.claim_next(provider)
      assert run_b_id == b.id
      assert {:ok, _, _} = Lease.refuse(token_b, :test)

      # Second cycle for both, both claimable.
      fresh_epoch!(a, 1)
      fresh_epoch!(b, 1)

      # Past A's boundary (A exhausted; B has 7 hours left): the ONLY
      # claimable epoch is B's -- the exhausted run's epoch is excluded
      # in the database, never handed out.
      fast_forward(3601)

      assert {:ok, epoch, token, run} = Lease.claim_next(provider)
      assert run.id == b.id
      assert epoch.run_id == b.id
      assert {:ok, _, _} = Lease.refuse(token, :test)

      # Only A's epoch remains: typed no-ready-work, A is never claimed.
      assert {:error, :no_ready_work} = Lease.claim_next(provider)
      assert unleased_running?(a.id)
    end
  end

  # ------------------------------------------------------------------
  # Epoch-dispatch lane: NextEpoch stops at the boundary
  # ------------------------------------------------------------------

  describe "NextEpoch budget gate" do
    test "past the budget no new epoch is constructed, even with max_cycles headroom" do
      run = started_run!(%{duration_budget_seconds: 3600, max_cycles: 3})
      complete_active_epoch!(run)

      fast_forward(3601)

      result = NextEpoch.advance_run(Ash.get!(Run, run.id, action: :read_unscoped))

      assert %{run_id: completed_run_id, outcome: :run_completed_budget_exhausted} = result
      assert completed_run_id == run.id
      assert result.receipt["within_budget"] == false
      assert result.receipt["epochs"]["completed"] == 1

      reloaded = Ash.get!(Run, run.id, action: :read_unscoped)
      assert reloaded.state == :completed
      assert Enum.count(epochs_of(run.id)) == 1, "no new epoch may be dispatched"
    end

    test "within budget the dispatch decision is unchanged (control)" do
      run = started_run!(%{duration_budget_seconds: 3600, max_cycles: 3})
      complete_active_epoch!(run)

      # Clock is still at t0: full budget remaining.
      assert %{run_id: advanced_run_id, outcome: :advanced, cycle: 1} =
               NextEpoch.advance_run(Ash.get!(Run, run.id, action: :read_unscoped))

      assert advanced_run_id == run.id

      assert Ash.get!(Run, run.id, action: :read_unscoped).state == :running
      assert Enum.count(epochs_of(run.id)) == 2
    end

    test "an active epoch on an exhausted run reports :budget_draining; a drained stale epoch completes the run" do
      # epoch_timeout_seconds 0: the epoch is stale the instant its
      # expected_at passes -- the existing MissedEpochs reap rule, driven
      # by its real wall clock (expected_at is written by the real clock
      # too, so the comparison stays honest).
      run =
        started_run!(%{duration_budget_seconds: 3600, max_cycles: 3, epoch_timeout_seconds: 0})

      epoch_to_running!(run)

      fast_forward(3601)

      assert %{run_id: draining_run_id, outcome: :budget_draining, epoch_state: :running} =
               NextEpoch.advance_run(Ash.get!(Run, run.id, action: :read_unscoped))

      assert draining_run_id == run.id

      assert Ash.get!(Run, run.id, action: :read_unscoped).state == :running

      # The existing reap rule (no new rule) transitions the stale epoch
      # to :missed with a sealed receipt; the NEXT advance completes the
      # drained run with its final receipt.
      assert %{run_id: reaped_run_id, missed: [missed_id]} = MissedEpochs.advance_run(run)
      assert reaped_run_id == run.id

      assert %{
               run_id: completed_run_id,
               outcome: :run_completed_budget_exhausted,
               receipt: receipt
             } =
               NextEpoch.advance_run(Ash.get!(Run, run.id, action: :read_unscoped))

      assert completed_run_id == run.id

      assert receipt["epochs"]["missed"] == 1
      assert Ash.get!(Run, run.id, action: :read_unscoped).state == :completed
      assert Ash.get!(Epoch, missed_id, action: :read_unscoped).state == :missed
    end
  end

  # ------------------------------------------------------------------
  # Drain guard: live leases finish, never abandoned
  # ------------------------------------------------------------------

  describe "drain_and_complete" do
    test "a live in-flight lease blocks completion (draining); once terminal, completes" do
      provider = "budget-drain-test"
      run = started_run!(%{provider: provider, duration_budget_seconds: 3600, max_cycles: 3})
      epoch_to_running!(run)

      # TTL 120 minutes so the lease is still LIVE past the 1-hour budget
      # boundary (a default 30-minute lease bound at t0 would itself be
      # expired by t0+3601 -- the drain would then be a reap, which the
      # NextEpoch test above already covers).
      assert {:ok, epoch, token, _run} = Lease.claim_next(provider, nil, lease_ttl_minutes: 120)

      fast_forward(3601)

      # Live lease: the run is NOT completed over it, and no error is
      # raised -- a typed draining report instead.
      assert {:error, {:draining, %{run_id: draining_id, active_epochs: 1}}} =
               DurationBudget.drain_and_complete(run, now: clock())

      assert draining_id == run.id

      assert Ash.get!(Run, run.id, action: :read_unscoped).state == :running

      # The worker finishes (here: a typed refusal closes it); the next
      # drain completes the run.
      assert {:ok, failed_epoch, _receipt} = Lease.refuse(token, :test)
      assert failed_epoch.id == epoch.id

      assert {:ok, %{run: completed, receipt: receipt}} =
               DurationBudget.drain_and_complete(run, now: clock())

      assert completed.state == :completed
      assert receipt["epochs"]["failed"] == 1
      assert receipt["within_budget"] == false
    end
  end

  # ------------------------------------------------------------------
  # Capacity governor: never more than capacity in flight at any instant
  # ------------------------------------------------------------------

  describe "Autonomic.dispatch_bounded capacity law" do
    test "enumerated grid: max observed in-flight never exceeds capacity" do
      {:ok, _} =
        Agent.start_link(fn -> %{in_flight: 0, max: 0} end, name: __MODULE__.FlightTracker)

      worker = fn _item, _sem_ctx ->
        Agent.update(__MODULE__.FlightTracker, fn t ->
          in_flight = t.in_flight + 1
          %{t | in_flight: in_flight, max: max(t.max, in_flight)}
        end)

        Process.sleep(1)

        Agent.update(__MODULE__.FlightTracker, fn t -> %{t | in_flight: t.in_flight - 1} end)
        :ok
      end

      for capacity <- [1, 2, 5], n <- [0, 1, 7, 23] do
        Agent.update(__MODULE__.FlightTracker, fn _ -> %{in_flight: 0, max: 0} end)

        items = Enum.to_list(1..n//1)
        results = Autonomic.dispatch_bounded(items, capacity, worker)

        assert results == Enum.map(items, fn _ -> {:ok, :ok} end),
               "capacity #{capacity}, #{n} items"

        tracker = Agent.get(__MODULE__.FlightTracker, & &1)
        assert tracker.in_flight == 0

        assert tracker.max <= capacity,
               "capacity #{capacity}, #{n} items: observed #{tracker.max} in flight"
      end
    end

    test "with real leases: at most 5 concurrent lease holders for a capacity-5 loop" do
      provider = "budget-capacity-test"
      run = create_run!(%{provider: provider})

      # 12 claimable epochs; the loop holds at most 5 workers in flight,
      # and each worker holds exactly one lease while in flight -- so at
      # most 5 leases can be live at any instant. Observed from INSIDE
      # every worker right after its real atomic claim (an over-capacity
      # observation would be definitive violation evidence).
      for cycle <- 0..11, do: fresh_epoch!(run, cycle)

      {:ok, _} =
        Agent.start_link(fn -> %{live: 0, max_live: 0, claims: 0} end,
          name: __MODULE__.LeaseTracker
        )

      worker = fn _item, _sem_ctx ->
        assert {:ok, _epoch, token, _run} = Lease.claim_next(provider)

        live = live_lease_count(run.id)

        Agent.update(__MODULE__.LeaseTracker, fn t ->
          %{t | live: live, max_live: max(t.max_live, live), claims: t.claims + 1}
        end)

        assert live <= 5

        # Hold the lease briefly so overlaps are real, then close.
        Process.sleep(2)
        assert {:ok, _, _} = Lease.refuse(token, :test)
        :ok
      end

      results = Autonomic.dispatch_bounded(Enum.to_list(1..12//1), 5, worker)
      assert Enum.all?(results, &(&1 == {:ok, :ok}))

      assert %{claims: 12, max_live: max_live} = Agent.get(__MODULE__.LeaseTracker, & &1)
      assert max_live <= 5
      assert max_live >= 2, "expected real overlap; got none"

      # Every epoch really went through the lease protocol exactly once.
      assert Enum.all?(epochs_of(run.id), &(&1.state == :failed))

      receipts = Receipt |> Ash.Query.for_read(:read) |> Ash.read!(authorize?: false)
      assert length(receipts) == 12
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp begin_session! do
    {:ok, session, :begun} = DurationBudget.find_or_begin_wave_session(now: clock())
    assert session.started_at == @t0
    assert session.wave_session == true
    session
  end

  defp create_run!(attrs) do
    Run
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(%{goal: "duration budget test run", max_cycles: 1}, attrs),
      authorize?: false
    )
    |> Ash.create!()
  end

  # A provider-pull run taken through the real `:start` action (writes
  # started_at from the injected clock and creates the first epoch).
  defp started_run!(attrs) do
    run =
      create_run!(
        Map.merge(
          %{provider: "budget-law-test", duration_budget_seconds: @budget, max_cycles: 3},
          attrs
        )
      )

    {:ok, run} =
      run
      |> Ash.Changeset.for_update(:start, %{exact_subject: "budget-law:#{run.id}"},
        authorize?: false
      )
      |> Ash.update()

    run
  end

  defp epoch_to_running!(run) do
    epoch = Enum.find(epochs_of(run.id), &(&1.state == :expected))

    epoch
    |> Ash.Changeset.for_update(:start, %{}, authorize?: false)
    |> Ash.update!()
  end

  defp complete_active_epoch!(run) do
    epoch = epoch_to_running!(run)

    epoch
    |> Ash.Changeset.for_update(:complete, %{final_head: "budget-law-head"}, authorize?: false)
    |> Ash.update!()
  end

  defp fresh_epoch!(run, cycle) do
    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{
        run_id: run.id,
        cycle: cycle,
        exact_subject: "budget-law:#{run.id}##{cycle}",
        state: :running,
        expected_at: clock()
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp epochs_of(run_id) do
    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(run_id == ^run_id)
    |> Ash.read!()
  end

  defp unleased_running?(run_id) do
    Enum.any?(epochs_of(run_id), &(&1.state == :running and is_nil(&1.lease_token)))
  end

  defp live_lease_count(run_id) do
    epochs_of(run_id)
    |> Enum.count(&(&1.state == :running and not is_nil(&1.lease_token)))
  end
end
