defmodule Xaas.Ultracode.SemanticWaveTest do
  # SemanticCase, not bare DataCase: the wave dispatch path (Task
  # .async_stream workers) and SemanticWork.materialize/2 both touch
  # Xaas.Repo Ash resources, so the suite needs the scoped shared
  # Xaas.Repo sandbox owner the template establishes -- the root fix for
  # the DBConnection.OwnershipError reds, and the mechanism that lets the
  # spawned dispatch processes join the test's sandboxed connection. The
  # template also restores the wave runner/state-dir env keys on exit.
  use Xaas.Ultracode.SemanticCase, async: false

  alias Xaas.Ultracode.{SemanticWave, SemanticWork}

  test "dispatches only already-materialized autonomic-wave policy epochs", %{
    sha: sha,
    state: state
  } do
    assert {:ok, %{epoch: wave_a}} =
             SemanticWork.materialize(semantic_descriptor(sha, "a", "autonomic_wave_attempt"))

    assert {:ok, %{epoch: wave_b}} =
             SemanticWork.materialize(semantic_descriptor(sha, "b", "autonomic_wave_attempt"))

    assert {:ok, %{epoch: continuous}} =
             SemanticWork.materialize(
               semantic_descriptor(sha, "continuous", "continuous_epoch_run")
             )

    parent = self()

    worker = fn epoch, _ctx ->
      send(parent, {:semantic_wave_dispatched, epoch.id})
      :ok
    end

    assert {:ok, report} =
             SemanticWave.run(capacity: 2, worker: worker, state_dir: state, max_items: 10)

    assert report["status"] == "DISPATCHED"
    assert report["sensed"] == 2
    assert report["dispatched"] == 2
    assert File.exists?(report["receipt_path"])

    dispatched =
      for _ <- 1..2 do
        assert_receive {:semantic_wave_dispatched, epoch_id}
        epoch_id
      end

    assert MapSet.new(dispatched) == MapSet.new([wave_a.id, wave_b.id])
    refute continuous.id in dispatched
  end

  test "an already-leased semantic Epoch is not redispatched", %{sha: sha, state: state} do
    assert {:ok, %{epoch: wave}} =
             SemanticWork.materialize(
               semantic_descriptor(sha, "leased", "autonomic_wave_attempt")
             )

    assert {:ok, _epoch, _token, _run} =
             Xaas.Ultracode.Lease.claim_next("zcode", "existing-worker", epoch_id: wave.id)

    parent = self()

    assert {:ok, report} =
             SemanticWave.run(
               worker: fn epoch, _ctx ->
                 send(parent, {:unexpected_dispatch, epoch.id})
                 :ok
               end,
               state_dir: state
             )

    assert report["status"] == "IDLE"
    assert report["sensed"] == 0
    refute_receive {:unexpected_dispatch, _}
  end

  test "AshOban registers semantic and legacy waves on the same serialized queue" do
    built =
      AshOban.config(
        Application.fetch_env!(:xaas, :ash_domains),
        Application.fetch_env!(:xaas, Oban)
      )

    {Oban.Plugins.Cron, opts} =
      Enum.find(built[:plugins], fn
        {Oban.Plugins.Cron, _opts} -> true
        _ -> false
      end)

    semantic_entry =
      Enum.find(opts[:crontab], fn
        {_cron, Xaas.Ultracode.Run.Workers.SemanticWave, _opts} -> true
        _ -> false
      end)

    legacy_entry =
      Enum.find(opts[:crontab], fn
        {_cron, Xaas.Ultracode.Run.Workers.AutonomicWave, _opts} -> true
        _ -> false
      end)

    assert {semantic_cron, _, _} = semantic_entry
    assert {legacy_cron, _, _} = legacy_entry
    assert to_string(semantic_cron) == "*/30 * * * *"
    assert to_string(legacy_cron) == "*/30 * * * *"
    assert Application.fetch_env!(:xaas, Oban)[:queues][:ultracode_wave] == 1
  end

  test "scheduled semantic action invokes capacity five without promoting standing", %{
    state: state
  } do
    {:ok, _pid} = Agent.start_link(fn -> nil end, name: __MODULE__.RunnerProbe)
    Application.put_env(:xaas, :ultracode_semantic_wave_runner, {__MODULE__, :capture_runner})
    Application.put_env(:xaas, :ultracode_semantic_wave_state_dir, state)

    assert {:ok, result} =
             Xaas.Ultracode.Run
             |> Ash.ActionInput.for_action(:semantic_wave, %{}, authorize?: false)
             |> Ash.run_action()

    assert Agent.get(__MODULE__.RunnerProbe, & &1) == [capacity: 5]
    assert result == %{status: "IDLE", receipt: "/tmp/semantic-wave.json"}
    refute Map.has_key?(result, :standing)
  end

  def capture_runner(opts) do
    Agent.update(__MODULE__.RunnerProbe, fn _ -> opts end)
    {:ok, %{"status" => "IDLE", "receipt_path" => "/tmp/semantic-wave.json"}}
  end
end
