defmodule Xaas.Ultracode.RunAutonomicWaveScheduleTest do
  @moduledoc """
  Qualification of the `:autonomic_wave` scheduled action on
  `Xaas.Ultracode.Run` (the 30-minute ultracode wave cron).

  Chicago-style boundaries, no LLM and no subprocess anywhere:

    * the schedule is REALLY registered: `AshOban.config/2` (the exact call
      `Xaas.Application` passes to the supervised Oban child) must merge a
      `*/30 * * * *` crontab entry whose job is the generated
      `Xaas.Ultracode.Run.Workers.AutonomicWave` worker, targeted at the
      `:ultracode_wave` queue -- the ULTRACODE-50 failure mode was schedules
      that existed in the DSL but never reached the running crontab, so the
      assertion is on the merged config, not the DSL;
    * the generated worker is REALLY bound to `:ultracode_wave`, that queue
      is listed with exactly one local execution slot, and AshOban's generated
      Oban worker carries `period: :infinity, states: :incomplete` uniqueness.
      The queue limit serializes execution per node; the worker uniqueness
      prevents a later identical scheduled wave from being inserted while the
      prior wave is still incomplete, including while it is executing;
    * running the `:autonomic_wave` action drives `Autonomic.run/1` with
      `capacity: 5` (the operator-ordered wave size) and maps the loop's
      report onto the action result, with a failed wave surfacing as a real
      action error. The runner is captured through the
      `:xaas, :ultracode_wave_runner` application-env seam the action reads;
      the real default is `Xaas.Ultracode.Autonomic`/`:run`, which is
      subprocess-qualified separately in `Xaas.Ultracode.AutonomicTest`.
    * the duration-budget law (the operator's "keep a 5 agent loop running
      for 8 hours" order) at the scheduler boundary: waves dispatch while
      budget remains; past start + 8h + epsilon NOTHING is dispatched, the
      session drains into terminal `:completed` with a final receipt, and
      later fires stay stopped (re-arm is an explicit opt-in); a stopped
      session with remaining budget resumes from the ORIGINAL started_at.
      The clock is injected through the law's `:xaas, :ultracode_clock`
      seam and fast-forwarded -- no test sleeps real hours.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Ultracode.Run

  # Fixed origin for the injected budget-law clock.
  @t0 ~U[2026-09-19T08:00:00.000000Z]

  def clock, do: Agent.get(__MODULE__.Clock, & &1)

  describe ":autonomic_wave schedule registration" do
    @tag :autonomic_wave_contract
    test "AshOban merges a */30 crontab entry for the generated worker" do
      built =
        AshOban.config(
          Application.fetch_env!(:xaas, :ash_domains),
          Application.fetch_env!(:xaas, Oban)
        )

      cron_plugin =
        Enum.find(built[:plugins], fn
          {Oban.Plugins.Cron, _opts} -> true
          _ -> false
        end)

      assert match?({Oban.Plugins.Cron, _}, cron_plugin)

      {_plugin, opts} = cron_plugin

      # AshOban builds crontab entries as {cron, worker, opts} tuples.
      entry =
        Enum.find(opts[:crontab], fn
          {_cron, Xaas.Ultracode.Run.Workers.AutonomicWave, _opts} -> true
          _ -> false
        end)

      assert entry, "no crontab entry for Xaas.Ultracode.Run.Workers.AutonomicWave"

      {cron, _worker, _entry_opts} = entry
      # Queue routing through a pinned `queue(:ultracode_wave)` is the exact
      # proven pattern of the four schedules already running in this repo
      # (e.g. `:tick` jobs observed on their pinned queue in oban_jobs).
      assert to_string(cron) == "*/30 * * * *"
    end

    @tag :autonomic_wave_contract
    test "generated worker is routed to the single-slot queue with incomplete-job uniqueness" do
      queues = Application.fetch_env!(:xaas, Oban)[:queues]
      worker_opts = Xaas.Ultracode.Run.Workers.AutonomicWave.__opts__()
      unique = worker_opts[:unique]

      assert queues[:ultracode_wave] == 1
      assert worker_opts[:queue] == :ultracode_wave
      assert unique[:period] == :infinity
      assert unique[:states] == :incomplete
      assert unique[:keys] == [:primary_key, :action_arguments, :tenant]
      assert :executing in Oban.Job.unique_states(unique[:states])
    end
  end

  describe "running the :autonomic_wave action" do
    setup do
      # The budget-gated action really writes the wave-session Run now,
      # so this file needs the same explicit Xaas.Repo sandbox checkout
      # as the other Xaas.Repo-backed Ultracode tests.
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

      {:ok, _pid} = Agent.start_link(fn -> nil end, name: __MODULE__.RunnerProbe)
      {:ok, _pid} = Agent.start_link(fn -> 0 end, name: __MODULE__.RunnerCount)

      Application.put_env(:xaas, :ultracode_wave_runner, {__MODULE__, :capture_runner})

      # The budget law's clock, injected at a fixed origin so boundary
      # tests can fast-forward without sleeping.
      {:ok, _pid} = Agent.start_link(fn -> @t0 end, name: __MODULE__.Clock)

      Application.put_env(:xaas, :ultracode_clock, {__MODULE__, :clock})

      # The Agent is linked to the test process and dies with it; on_exit
      # only restores the application env.
      on_exit(fn ->
        Application.delete_env(:xaas, :ultracode_wave_runner)
        Application.delete_env(:xaas, :ultracode_clock)
        Application.delete_env(:xaas, :ultracode_wave_rearm)
      end)

      :ok
    end

    @tag :autonomic_wave_contract
    test "drives Autonomic.run with capacity 5 and surfaces the wave report" do
      {:ok, result} =
        Run
        |> Ash.ActionInput.for_action(:autonomic_wave, %{}, authorize?: false)
        |> Ash.run_action()

      assert Agent.get(__MODULE__.RunnerProbe, & &1) == [capacity: 5]
      assert result.standing == "PARTIAL_ALIVE"
      assert result.receipt == "/tmp/fake-wave-receipt.json"

      # The dispatched wave is counted on the (first) standing-wave
      # session Run, with the budget state on the record.
      assert %{run_id: run_id, dispatch: :allowed, waves_run: 1} = result.budget
      session = Ash.get!(Run, run_id, action: :read_unscoped)
      assert session.wave_session == true
      assert session.state == :running
      assert session.started_at == @t0
      assert session.duration_budget_seconds == 28_800
    end

    @tag :autonomic_wave_contract
    test "a failed wave is an action error, never a silently-ok tick" do
      Application.put_env(:xaas, :ultracode_wave_runner, {__MODULE__, :failing_runner})

      assert {:error, %Ash.Error.Unknown{} = error} =
               Run
               |> Ash.ActionInput.for_action(:autonomic_wave, %{}, authorize?: false)
               |> Ash.run_action()

      assert Exception.message(error) =~ "backlog sensing failed"
    end

    test "past the duration budget: no new dispatch, drained, terminal completed, receipt" do
      # Wave 1 within budget, wave 2 still within budget (continuous
      # waves), then the boundary passes.
      for _ <- 1..2 do
        assert {:ok, %{budget: %{dispatch: :allowed}}} =
                 Run
                 |> Ash.ActionInput.for_action(:autonomic_wave, %{}, authorize?: false)
                 |> Ash.run_action()
      end

      assert Agent.get(__MODULE__.RunnerCount, & &1) == 2

      # start + 8h + epsilon.
      Agent.update(__MODULE__.Clock, &DateTime.add(&1, 28_800 + 1, :second))

      result =
        Run
        |> Ash.ActionInput.for_action(:autonomic_wave, %{}, authorize?: false)
        |> Ash.run_action!()

      # NO new dispatch: the runner was called exactly twice, ever.
      assert Agent.get(__MODULE__.RunnerCount, & &1) == 2
      assert result.standing == "REFUSED_BUDGET_EXHAUSTED"

      assert %{dispatch: :budget_exhausted, draining: false, session_state: "completed"} =
               result.budget

      assert result.budget.waves_run == 2

      receipt = result.budget.receipt
      assert receipt["within_budget"] == false
      assert receipt["duration_actual_seconds"] == 28_800 + 1
      assert receipt["waves_run"] == 2
      assert receipt["human_inputs"] == 0

      # The session Run itself is terminally completed, durably.
      session = Ash.get!(Run, result.budget.run_id, action: :read_unscoped)
      assert session.state == :completed
    end

    test "after the 8-hour run completed the loop stays stopped (re-arm is opt-in)" do
      # Run the full budget out.
      assert {:ok, %{budget: %{dispatch: :allowed}}} =
               Run
               |> Ash.ActionInput.for_action(:autonomic_wave, %{}, authorize?: false)
               |> Ash.run_action()

      Agent.update(__MODULE__.Clock, &DateTime.add(&1, 28_800 + 1, :second))

      assert {:ok, %{budget: %{dispatch: :budget_exhausted, session_state: "completed"}}} =
               Run
               |> Ash.ActionInput.for_action(:autonomic_wave, %{}, authorize?: false)
               |> Ash.run_action()

      calls = Agent.get(__MODULE__.RunnerCount, & &1)

      # A later fire: no running session, terminal session on record --
      # nothing is dispatched and no new session silently begins.
      Agent.update(__MODULE__.Clock, &DateTime.add(&1, 3600, :second))

      result =
        Run
        |> Ash.ActionInput.for_action(:autonomic_wave, %{}, authorize?: false)
        |> Ash.run_action!()

      assert Agent.get(__MODULE__.RunnerCount, & &1) == calls
      assert result.standing == "REFUSED_BUDGET_EXHAUSTED"
      assert result.budget.dispatch == :stopped_after_budget
      assert result.budget.session_state == "completed"
      assert result.budget.receipt["waves_run"] == 1
    end

    test "a stopped run with remaining budget resumes from started_at, never reset" do
      assert {:ok, %{budget: %{dispatch: :allowed, waves_run: 1, run_id: run_id}}} =
               Run
               |> Ash.ActionInput.for_action(:autonomic_wave, %{}, authorize?: false)
               |> Ash.run_action()

      # "Stopped" for 2 hours (no fires), then resume: the remaining
      # budget is wall-clock from the ORIGINAL started_at.
      Agent.update(__MODULE__.Clock, &DateTime.add(&1, 2 * 3600, :second))

      result =
        Run
        |> Ash.ActionInput.for_action(:autonomic_wave, %{}, authorize?: false)
        |> Ash.run_action!()

      assert %{dispatch: :allowed, waves_run: 2, remaining_seconds: remaining} = result.budget
      assert remaining == 6 * 3600
      assert result.budget.run_id == run_id

      session = Ash.get!(Run, run_id, action: :read_unscoped)
      assert session.started_at == @t0, "resume must never reset the wall clock"
    end
  end

  # -- test runner seams -----------------------------------------------------

  def capture_runner(opts) do
    # The action may execute in a supervised task process, so the capture
    # goes through a named Agent rather than the calling process dictionary.
    Agent.update(__MODULE__.RunnerProbe, fn _ -> opts end)
    Agent.update(__MODULE__.RunnerCount, &(&1 + 1))
    {:ok, %{"standing" => "PARTIAL_ALIVE", "receipt_path" => "/tmp/fake-wave-receipt.json"}}
  end

  def failing_runner(_opts), do: {:error, "backlog sensing failed"}
end
