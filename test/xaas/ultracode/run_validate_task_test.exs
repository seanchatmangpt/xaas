defmodule Mix.Tasks.Xaas.RunValidateTaskTest do
  @moduledoc """
  In-process exercise of `mix xaas.run_validate` for the paths that do
  NOT call `System.halt/1`: the validated path (exit 0 behavior: prints
  the verdict and the per-epoch accounting) and the two typed-refusal
  paths (`Mix.raise` on usage error and on missing OCEL emitter). The
  `:not_validated` path's real exit code 1 is observed out-of-test
  against a real mutated log fixture -- in-process it would halt this
  very test VM (same reasoning as
  `Mix.Tasks.Xaas.VerifyAndCommitTest`'s moduledoc, this repo's
  precedent for exactly this hazard).
  """

  use ExUnit.Case, async: false

  @moduletag :ultracode

  @run "run-task-1"

  defp three_epoch_log do
    events = [
      %{
        "id" => "claim-ep-0",
        "type" => "epoch_claimed",
        "time" => "2026-09-19T00:00:00Z",
        "attributes" => %{"epoch_id" => "ep-0", "run_id" => @run},
        "relationships" => [
          %{"objectId" => "ep-0", "qualifier" => "epoch"},
          %{"objectId" => @run, "qualifier" => "run"}
        ]
      },
      %{
        "id" => "close-ep-0",
        "type" => "receipt_closed",
        "time" => "2026-09-19T00:10:00Z",
        "attributes" => %{"epoch_id" => "ep-0", "run_id" => @run, "verification" => "passed"},
        "relationships" => [
          %{"objectId" => "ep-0", "qualifier" => "epoch"},
          %{"objectId" => @run, "qualifier" => "run"}
        ]
      }
    ]

    %{
      "objectTypes" => ["run", "epoch"],
      "eventTypes" => ["epoch_claimed", "receipt_closed"],
      "objects" => [%{"id" => @run, "type" => "run"}, %{"id" => "ep-0", "type" => "epoch"}],
      "events" => events
    }
  end

  defp write_log! do
    path =
      Path.join(
        System.tmp_dir!(),
        "run_validate_task_#{System.system_time(:millisecond)}-#{System.unique_integer()}.json"
      )

    File.write!(path, Jason.encode!(three_epoch_log()))
    on_exit(fn -> File.rm(path) end)
    path
  end

  test "a validating log file prints VALIDATED and the per-epoch accounting, no halt" do
    path = write_log!()

    output =
      ExUnit.CaptureIO.capture_io(:stdio, fn ->
        Mix.Task.rerun("xaas.run_validate", [path, "--run-id", @run])
      end)

    assert output =~ "VALIDATED"
    assert output =~ "ep-0"
    assert output =~ "passed"
    assert output =~ "max workers in flight: 1 (capacity 5)"
  end

  test "--per-repo-capacity parses and prints the per-repo accounting" do
    # One repo-bound epoch (Repo object + repo-qualified relationship,
    # the egress multi-repo shape): validates under a per-repo cap of 1
    # and prints the per-repo table.
    events = [
      %{
        "id" => "claim-ep-0",
        "type" => "epoch_claimed",
        "time" => "2026-09-19T00:00:00Z",
        "attributes" => %{"epoch_id" => "ep-0", "run_id" => @run},
        "relationships" => [
          %{"objectId" => "ep-0", "qualifier" => "epoch"},
          %{"objectId" => @run, "qualifier" => "run"},
          %{"objectId" => "zoela_phx", "qualifier" => "repo"}
        ]
      },
      %{
        "id" => "close-ep-0",
        "type" => "receipt_closed",
        "time" => "2026-09-19T00:10:00Z",
        "attributes" => %{"epoch_id" => "ep-0", "run_id" => @run, "verification" => "passed"},
        "relationships" => [
          %{"objectId" => "ep-0", "qualifier" => "epoch"},
          %{"objectId" => @run, "qualifier" => "run"},
          %{"objectId" => "zoela_phx", "qualifier" => "repo"}
        ]
      }
    ]

    log = %{
      "objectTypes" => ["run", "epoch", "Repo"],
      "eventTypes" => ["epoch_claimed", "receipt_closed"],
      "objects" => [
        %{"id" => @run, "type" => "run"},
        %{"id" => "ep-0", "type" => "epoch"},
        %{"id" => "zoela_phx", "type" => "Repo"}
      ],
      "events" => events
    }

    path =
      Path.join(
        System.tmp_dir!(),
        "run_validate_task_repo_#{System.system_time(:millisecond)}-#{System.unique_integer()}.json"
      )

    File.write!(path, Jason.encode!(log))
    on_exit(fn -> File.rm(path) end)

    output =
      ExUnit.CaptureIO.capture_io(:stdio, fn ->
        Mix.Task.rerun("xaas.run_validate", [path, "--per-repo-capacity", "1"])
      end)

    assert output =~ "VALIDATED"
    assert output =~ "max workers in flight per repo:"
    assert output =~ "repo zoela_phx: 1 (per-repo cap 1)"
  end

  test "no positional argument is a usage refusal" do
    assert_raise Mix.Error, ~r/usage: mix xaas.run_validate/, fn ->
      Mix.Task.rerun("xaas.run_validate", [])
    end
  end

  # The emitter seam (`Xaas.Ultracode.OcelEgress.derive_run/1` is the
  # real default) needs persisted Run rows -- real DB state these pure
  # task tests do not fabricate. The seam is exercised through the
  # configured module with an honest stand-in (below): one that returns
  # a real log (proving run-id input flows derive -> validate ->
  # VALIDATED without re-deriving anything here), one that returns the
  # emitter's own typed error, and a missing module (the typed
  # refusal). The stand-in is a real module with the real derive_run/1
  # contract; the task and `RunValidation.emit_log/1` under test run
  # for real.
  defmodule TestEmitterStub do
    @moduledoc "Real-module stand-in for the configured OCEL emitter: returns whatever the test stored."

    def derive_run(_run_id), do: Application.fetch_env!(:xaas, :run_validate_test_emitter_result)
  end

  defp with_emitter(return, fun) do
    Application.put_env(:xaas, :ultracode_ocel_log_emitter, TestEmitterStub)
    Application.put_env(:xaas, :run_validate_test_emitter_result, return)

    on_exit(fn ->
      Application.delete_env(:xaas, :ultracode_ocel_log_emitter)
      Application.delete_env(:xaas, :run_validate_test_emitter_result)
    end)

    fun.()
  end

  test "run-id input flows through the configured emitter: derive -> validate -> VALIDATED" do
    with_emitter({:ok, three_epoch_log()}, fn ->
      output =
        ExUnit.CaptureIO.capture_io(:stdio, fn ->
          Mix.Task.rerun("xaas.run_validate", [@run])
        end)

      assert output =~ "VALIDATED"
      assert output =~ "ep-0"
      assert output =~ "passed"
    end)
  end

  test "the emitter's own typed error surfaces as a raise naming the run" do
    with_emitter({:error, :run_not_found}, fn ->
      assert_raise Mix.Error, ~r/emitter failed for run #{@run}.*:run_not_found/s, fn ->
        Mix.Task.rerun("xaas.run_validate", [@run])
      end
    end)
  end

  test "a missing emitter module is a typed refusal, not a fabricated log" do
    Application.put_env(:xaas, :ultracode_ocel_log_emitter, Xaas.Ultracode.DoesNotExistEmitter)
    on_exit(fn -> Application.delete_env(:xaas, :ultracode_ocel_log_emitter) end)

    assert_raise Mix.Error, ~r/REFUSED_NO_EMITTER/, fn ->
      Mix.Task.rerun("xaas.run_validate", ["some-run-id"])
    end
  end
end
