defmodule Xaas.Ultracode.ItemRunLifecycleTest do
  @moduledoc """
  Chicago-style qualification of the wave-2 finding fix: item-level
  `ultracode_runs` rows TRANSITION now.

  The finding: the Autonomic loop created one Run row per work item per
  attempt, born `:pending`, and NEVER transitioned it -- 1043 rows sat
  `pending` while epochs/receipts carried the real terminality, so the DB
  misstated reality. The fix (and what is under test here, against real
  sandboxed Postgres, real Ash actions, real authorization -- no mocks):

    * the LIVE edges: an attempt's run opens `:pending -> :running` when
      its epoch exists, and closes through the admitted `:transition_state`
      action (court-grounded classify law, `:ultracode_reactor` system
      authority -- the deny floor really checks the actor: the no-actor
      case is asserted to be REFUSED) at the attempt's terminal outcome;
    * the exhaustion edge lands on the state machine's lawful
      abandoned-work edge (`:abandoned`/`:blocked` -- the same edge
      `Run.:stop` uses), via `RunTransitionAllowed`-admitted edges only;
    * a double transition is guarded (idempotent `:already_terminal`,
      `terminal_at` untouched);
    * the reconcile sweep (`Xaas.Ultracode.RunReconciliation`,
      `mix xaas.ultracode.reconcile_runs`) transitions a stuck fixture
      through the same admitted walk and LEAVES unknowns pending
      (epoch-less rows, runs with live epochs) with honest reasons.
  """

  use ExUnit.Case, async: false

  @moduletag :ultracode

  alias Xaas.Ultracode.{Epoch, ItemRuns, Receipt, Run, RunReconciliation}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # ------------------------------------------------------------------
  # Fixtures (the same shapes the Autonomic loop itself writes:
  # Run :create, Epoch :create with a :running-able state, Receipt :seal)
  # ------------------------------------------------------------------

  defp sys_actor, do: Xaas.SystemAuthority.new(:ultracode_reactor)

  defp item_run! do
    Run
    |> Ash.Changeset.for_create(
      :create,
      %{goal: "item_run_lifecycle_test item attempt", max_cycles: 1},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp epoch!(run, state) do
    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{
        run_id: run.id,
        cycle: 0,
        exact_subject:
          "xaas-autonomic:item_run_lifecycle_test##{System.unique_integer([:positive])}:#{run.id}",
        state: state
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp seal!(epoch, outcome, evidence) do
    Receipt
    |> Ash.Changeset.for_create(
      :seal,
      %{
        epoch_id: epoch.id,
        subject: epoch.exact_subject,
        outcome: outcome,
        evidence: evidence,
        sealed_at: DateTime.utc_now()
      }
    )
    |> Ash.create!(actor: sys_actor())
  end

  defp court_pass_evidence,
    do: %{"head_verified" => true, "fabric_verifier" => %{"status" => "pass"}}

  defp court_fail_evidence,
    do: %{"head_verified" => true, "fabric_verifier" => %{"status" => "fail", "reason" => "x"}}

  defp fresh_run!(run_id), do: Ash.get!(Run, run_id, action: :read_unscoped)

  # ------------------------------------------------------------------
  # The live edges
  # ------------------------------------------------------------------

  test "attempt start opens the run :pending -> :running through the admitted edge" do
    run = item_run!()

    assert {:ok, {:transitioned, :running}} = ItemRuns.open!(run.id)
    assert fresh_run!(run.id).state == :running

    # Idempotent: an already-running (or terminal) run is left alone.
    assert {:ok, :already_running} = ItemRuns.open!(run.id)
  end

  test "attempt completion transitions the item run to :completed/:admitted with terminal_at" do
    run = item_run!()
    {:ok, _} = ItemRuns.open!(run.id)
    epoch = epoch!(run, :completed)
    seal!(epoch, :alive, court_pass_evidence())

    assert {:ok, {:transitioned, :completed}} = ItemRuns.close_attempt!(run, epoch)

    closed = fresh_run!(run.id)
    assert closed.state == :completed
    assert closed.standing == :admitted
    assert closed.terminal_at != nil
  end

  test "an honest partial_alive on a court-pass head also completes the run" do
    run = item_run!()
    {:ok, _} = ItemRuns.open!(run.id)
    epoch = epoch!(run, :completed)
    seal!(epoch, :partial_alive, court_pass_evidence())

    assert {:ok, {:transitioned, :completed}} = ItemRuns.close_attempt!(run, epoch)
    assert %{state: :completed, standing: :admitted} = fresh_run!(run.id)
  end

  test "exhaustion lands on the lawful abandoned-work edge (:abandoned/:blocked)" do
    # The final attempt's run: a falsified epoch, and the item is out of
    # attempts -- the item gave up on this attempt's work.
    run = item_run!()
    epoch = epoch!(run, :failed)

    assert {:ok, {:transitioned, :abandoned}} =
             ItemRuns.close_attempt!(run, epoch, exhausted: true)

    closed = fresh_run!(run.id)
    assert closed.state == :abandoned
    assert closed.standing == :blocked
    assert closed.terminal_at != nil
  end

  test "a mid-flight attempt failure closes :failed/:refused (court fail, falsified)" do
    run = item_run!()
    {:ok, _} = ItemRuns.open!(run.id)
    epoch = epoch!(run, :completed)
    seal!(epoch, :build_broken, court_fail_evidence())

    assert {:ok, {:transitioned, :failed}} = ItemRuns.close_attempt!(run, epoch)
    assert %{state: :failed, standing: :refused} = fresh_run!(run.id)
  end

  test "a completed epoch with NO closing receipt closes :failed/:blocked (court infra)" do
    run = item_run!()
    {:ok, _} = ItemRuns.open!(run.id)
    epoch = epoch!(run, :completed)
    # A heartbeat is real but is never a closing receipt (no head_verified).
    seal!(epoch, :heartbeat, %{"tick" => true})

    assert {:ok, {:transitioned, :failed}} = ItemRuns.close_attempt!(run, epoch)
    assert %{state: :failed, standing: :blocked} = fresh_run!(run.id)
  end

  test "a missed epoch lands on :abandoned/:blocked" do
    run = item_run!()
    {:ok, _} = ItemRuns.open!(run.id)
    epoch = epoch!(run, :missed)
    seal!(epoch, :blocked, %{"expected_state" => "completed", "observed_state" => "missed"})

    assert {:ok, {:transitioned, :abandoned}} = ItemRuns.close_attempt!(run, epoch)
    assert %{state: :abandoned, standing: :blocked} = fresh_run!(run.id)
  end

  test "an epoch that has not ended leaves the run open -- no invented terminality" do
    run = item_run!()
    {:ok, _} = ItemRuns.open!(run.id)
    epoch = epoch!(run, :running)

    assert {:ok, {:left_open, {:epoch_not_terminal, epoch_id, :running}}} =
             ItemRuns.close_attempt!(run, epoch)

    assert epoch_id == epoch.id
    assert %{state: :running, terminal_at: nil} = fresh_run!(run.id)
  end

  test "the transition is ADMITTED, not ambient: no actor is refused by the deny floor" do
    run = item_run!()
    {:ok, _} = ItemRuns.open!(run.id)

    # A LAWFUL edge (`:running -> :completed`) attempted WITHOUT the
    # admitted system authority: the deny floor refuses it -- proving the
    # real transitions in this file pass BECAUSE of the actor, not
    # around authorization.
    assert {:error, %Ash.Error.Forbidden{}} =
             fresh_run!(run.id)
             |> Ash.Changeset.for_update(:transition_state, %{state: :completed})
             |> Ash.update()
  end

  # ------------------------------------------------------------------
  # The guard
  # ------------------------------------------------------------------

  test "double transition is guarded: second close is :already_terminal, terminal_at stable" do
    run = item_run!()
    epoch = epoch!(run, :completed)
    seal!(epoch, :alive, court_pass_evidence())

    assert {:ok, {:transitioned, :completed}} = ItemRuns.close!(run.id, :completed, :admitted)
    %Run{terminal_at: first_terminal_at} = fresh_run!(run.id)

    assert {:ok, :already_terminal} = ItemRuns.close!(run.id, :completed, :admitted)
    assert {:ok, :already_terminal} = ItemRuns.close!(run.id, :failed, :refused)

    assert %Run{state: :completed, terminal_at: ^first_terminal_at} = fresh_run!(run.id)
  end

  test "close! from a historical :pending row lawfully walks :pending -> :running -> terminal" do
    run = item_run!()
    # No open!/1 -- the stuck historical shape.
    epoch = epoch!(run, :completed)
    seal!(epoch, :alive, court_pass_evidence())

    assert {:ok, {:transitioned, :completed}} = ItemRuns.close!(run.id, :completed, :admitted)
    assert %{state: :completed, standing: :admitted} = fresh_run!(run.id)
  end

  # ------------------------------------------------------------------
  # The reconcile sweep
  # ------------------------------------------------------------------

  test "reconcile dry-run transitions nothing; live sweep closes the stuck fixture" do
    stuck = item_run!()
    stuck_epoch = epoch!(stuck, :completed)
    seal!(stuck_epoch, :alive, court_pass_evidence())

    # Unknown #1: an epoch-less row -- no evidence, never guessed closed.
    epochless = item_run!()

    # Unknown #2: a run with a live epoch -- never closed over in-flight work.
    live_work = item_run!()
    _live_epoch = epoch!(live_work, :running)

    dry = RunReconciliation.sweep(dry_run: true)
    assert dry.dry_run
    assert dry.transitions == 0
    assert dry.would_transition >= 1
    assert dry.before == dry.after
    assert %{state: :pending, terminal_at: nil} = fresh_run!(stuck.id)

    report = RunReconciliation.sweep([])
    refute report.dry_run
    assert report.transitions >= 1
    assert report.after != report.before or report.transitions == 0

    assert %{state: :completed, standing: :admitted} = closed = fresh_run!(stuck.id)
    assert closed.terminal_at != nil

    assert %{state: :pending} = fresh_run!(epochless.id)
    assert %{state: :pending} = fresh_run!(live_work.id)

    assert report.skipped[:no_epochs][:count] >= 1
    assert report.skipped[:epoch_not_terminal][:count] >= 1
  end

  test "reconcile is idempotent: a second sweep reports zero transitions" do
    stuck = item_run!()
    epoch = epoch!(stuck, :completed)
    seal!(epoch, :partial_alive, court_pass_evidence())

    first = RunReconciliation.sweep([])
    assert first.transitions >= 1

    second = RunReconciliation.sweep([])
    assert second.transitions == 0
    assert second.candidates == 0
    assert %{state: :completed} = fresh_run!(stuck.id)
  end

  # ------------------------------------------------------------------
  # The mix task (in-process; no System.halt anywhere in this task)
  # ------------------------------------------------------------------

  test "mix xaas.ultracode.reconcile_runs --dry-run then live prints the census" do
    stuck = item_run!()
    epoch = epoch!(stuck, :completed)
    seal!(epoch, :alive, court_pass_evidence())

    import ExUnit.CaptureIO

    dry_output =
      capture_io(:stdio, fn ->
        Mix.Task.rerun("xaas.ultracode.reconcile_runs", ["--dry-run"])
      end)

    assert dry_output =~ "DRY RUN"
    assert dry_output =~ "would close:"
    assert dry_output =~ "before (GROUP BY state):"
    assert dry_output =~ "after  (GROUP BY state):"
    assert %{state: :pending} = fresh_run!(stuck.id)

    live_output =
      capture_io(:stdio, fn ->
        Mix.Task.rerun("xaas.ultracode.reconcile_runs", [])
      end)

    assert live_output =~ "LIVE"
    assert live_output =~ "closed:"
    assert %{state: :completed, standing: :admitted} = fresh_run!(stuck.id)
  end
end
