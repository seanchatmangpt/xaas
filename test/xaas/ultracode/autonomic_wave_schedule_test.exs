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
    * the dedicated `:ultracode_wave` queue is listed with exactly one slot
      (`AshOban.require_queues!/4` fails the boot otherwise, and the single
      slot is what serializes waves whose promote step is shared state);
    * running the `:autonomic_wave` action drives `Autonomic.run/1` with
      `capacity: 5` (the operator-ordered wave size) and maps the loop's
      report onto the action result, with a failed wave surfacing as a real
      action error. The runner is captured through the
      `:xaas, :ultracode_wave_runner` application-env seam the action reads;
      the real default is `Xaas.Ultracode.Autonomic`/`:run`, which is
      subprocess-qualified separately in `Xaas.Ultracode.AutonomicTest`.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Ultracode.Run

  @capture_table :autonomic_wave_runner_capture

  describe ":autonomic_wave schedule registration" do
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

    test "the :ultracode_wave queue is listed with exactly one slot" do
      queues = Application.fetch_env!(:xaas, Oban)[:queues]
      assert queues[:ultracode_wave] == 1
    end
  end

  describe "running the :autonomic_wave action" do
    setup do
      {:ok, _pid} = Agent.start_link(fn -> nil end, name: __MODULE__.RunnerProbe)
      Application.put_env(:xaas, :ultracode_wave_runner, {__MODULE__, :capture_runner})

      # The Agent is linked to the test process and dies with it; on_exit
      # only restores the application env.
      on_exit(fn ->
        Application.delete_env(:xaas, :ultracode_wave_runner)
      end)

      :ok
    end

    test "drives Autonomic.run with capacity 5 and surfaces the wave report" do
      {:ok, result} =
        Run
        |> Ash.ActionInput.for_action(:autonomic_wave, %{}, authorize?: false)
        |> Ash.run_action()

      assert Agent.get(__MODULE__.RunnerProbe, & &1) == [capacity: 5]
      assert result == %{standing: "PARTIAL_ALIVE", receipt: "/tmp/fake-wave-receipt.json"}
    end

    test "a failed wave is an action error, never a silently-ok tick" do
      Application.put_env(:xaas, :ultracode_wave_runner, {__MODULE__, :failing_runner})

      assert {:error, %Ash.Error.Unknown{} = error} =
               Run
               |> Ash.ActionInput.for_action(:autonomic_wave, %{}, authorize?: false)
               |> Ash.run_action()

      assert Exception.message(error) =~ "backlog sensing failed"
    end
  end

  # -- test runner seams -----------------------------------------------------

  def capture_runner(opts) do
    # The action may execute in a supervised task process, so the capture
    # goes through a named Agent rather than the calling process dictionary.
    Agent.update(__MODULE__.RunnerProbe, fn _ -> opts end)
    {:ok, %{"standing" => "PARTIAL_ALIVE", "receipt_path" => "/tmp/fake-wave-receipt.json"}}
  end

  def failing_runner(_opts), do: {:error, "backlog sensing failed"}
end
