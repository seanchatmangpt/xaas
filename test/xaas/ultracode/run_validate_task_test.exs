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
    path = Path.join(System.tmp_dir!(), "run_validate_task_#{System.unique_integer()}.json")
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

  test "no positional argument is a usage refusal" do
    assert_raise Mix.Error, ~r/usage: mix xaas.run_validate/, fn ->
      Mix.Task.rerun("xaas.run_validate", [])
    end
  end

  test "run-id input with no emitter on the branch is a typed refusal, not a fabricated log" do
    assert_raise Mix.Error, ~r/REFUSED_NO_EMITTER/, fn ->
      Mix.Task.rerun("xaas.run_validate", ["some-run-id"])
    end
  end
end
