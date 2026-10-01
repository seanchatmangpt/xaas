defmodule Xaas.Ocel.OcpmTest do
  @moduledoc """
  Golden-fixture tests for XA-3009 (`Xaas.Ocel.Ocpm`).

  The fixture (`golden_document/0`) is a fabricated but realistic OCEL 2.0
  document in the exact shape `Xaas.Ultracode.OcelEgress.build_document/3`
  emits: one Run, two Epochs (one completed under lease, one missed), one
  Worker, two Receipts, one Worktree path, and the eleven lifecycle events
  the egress emits for that shape (including object-to-object
  relationships inside `ocel:objects`, which MUST NOT count as
  interactions). Every expected map below is hand-computed from that
  fixture -- the exact-map assertions are the ticket's falsifier run
  ("counts differ from a hand-computed golden on the fixture doc").

  Also a real subprocess qualification of `mix xaas.ocel.ocpm` (the
  `Mix.Tasks.Xaas.OcelValidateTest` precedent: real file on disk, real OS
  `mix` process, real exit code; tagged `:subprocess`, excluded from the
  default fast loop per test/test_helper.exs). Nothing mocked.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ocel.Ocpm

  # --------------------------------------------------------------------------------
  # Golden fixture: exact OcelEgress.build_document/3 shape, hand-computed golden
  # --------------------------------------------------------------------------------

  defp golden_document do
    %{
      "ocel:objectTypes" =>
        Enum.map(["Run", "Epoch", "Worker", "Receipt", "Worktree"], fn name ->
          %{"name" => name}
        end),
      "ocel:eventTypes" =>
        Enum.map(
          [
            "run_started",
            "epoch_scheduled",
            "epoch_started",
            "epoch_claimed",
            "epoch_completed",
            "epoch_missed",
            "receipt_closed",
            "heartbeat_recorded",
            "verification_passed",
            "refused"
          ],
          fn name -> %{"name" => name} end
        ),
      "ocel:events" => [
        %{
          "id" => "run_started:run-1",
          "type" => "run_started",
          "time" => "2026-09-30T09:00:00Z",
          "attributes" => %{},
          "relationships" => [rel("run-1", "run")]
        },
        %{
          "id" => "epoch_scheduled:epoch-1",
          "type" => "epoch_scheduled",
          "time" => "2026-09-30T09:00:01Z",
          "attributes" => %{"cycle" => 0},
          "relationships" => [rel("run-1", "run"), rel("epoch-1", "epoch"), rel("/wt/demo", "worktree")]
        },
        %{
          "id" => "epoch_scheduled:epoch-2",
          "type" => "epoch_scheduled",
          "time" => "2026-09-30T09:00:02Z",
          "attributes" => %{"cycle" => 0},
          "relationships" => [rel("run-1", "run"), rel("epoch-2", "epoch"), rel("/wt/demo", "worktree")]
        },
        %{
          "id" => "epoch_started:epoch-1",
          "type" => "epoch_started",
          "time" => "2026-09-30T09:01:00Z",
          "attributes" => %{"cycle" => 0},
          "relationships" => [rel("run-1", "run"), rel("epoch-1", "epoch"), rel("/wt/demo", "worktree")]
        },
        %{
          "id" => "epoch_claimed:epoch-1",
          "type" => "epoch_claimed",
          "time" => "2026-09-30T09:01:30Z",
          "attributes" => %{"cycle" => 0},
          "relationships" => [
            rel("run-1", "run"),
            rel("epoch-1", "epoch"),
            rel("/wt/demo", "worktree"),
            rel("worker-a", "worker")
          ]
        },
        %{
          "id" => "epoch_completed:epoch-1",
          "type" => "epoch_completed",
          "time" => "2026-09-30T09:05:00Z",
          "attributes" => %{"cycle" => 0},
          "relationships" => [
            rel("run-1", "run"),
            rel("epoch-1", "epoch"),
            rel("/wt/demo", "worktree"),
            rel("worker-a", "worker")
          ]
        },
        %{
          "id" => "epoch_missed:epoch-2",
          "type" => "epoch_missed",
          "time" => "2026-09-30T09:06:00Z",
          "attributes" => %{"cycle" => 0},
          "relationships" => [rel("run-1", "run"), rel("epoch-2", "epoch"), rel("/wt/demo", "worktree")]
        },
        %{
          "id" => "receipt_closed:receipt-1",
          "type" => "receipt_closed",
          "time" => "2026-09-30T09:05:01Z",
          "attributes" => %{"outcome" => "alive"},
          "relationships" => [
            rel("run-1", "run"),
            rel("epoch-1", "epoch"),
            rel("/wt/demo", "worktree"),
            rel("worker-a", "worker"),
            rel("receipt-1", "receipt")
          ]
        },
        %{
          "id" => "heartbeat_recorded:receipt-2",
          "type" => "heartbeat_recorded",
          "time" => "2026-09-30T09:05:30Z",
          "attributes" => %{"outcome" => "heartbeat"},
          "relationships" => [
            rel("run-1", "run"),
            rel("epoch-1", "epoch"),
            rel("/wt/demo", "worktree"),
            rel("worker-a", "worker"),
            rel("receipt-2", "receipt")
          ]
        },
        %{
          "id" => "verification_passed:receipt-1",
          "type" => "verification_passed",
          "time" => "2026-09-30T09:05:02Z",
          "attributes" => %{"verifier_status" => "pass"},
          "relationships" => [
            rel("run-1", "run"),
            rel("epoch-1", "epoch"),
            rel("/wt/demo", "worktree"),
            rel("worker-a", "worker"),
            rel("receipt-1", "receipt")
          ]
        },
        %{
          "id" => "refused:receipt-2",
          "type" => "refused",
          "time" => "2026-09-30T09:06:30Z",
          "attributes" => %{"outcome" => "refused"},
          "relationships" => [
            rel("run-1", "run"),
            rel("epoch-1", "epoch"),
            rel("/wt/demo", "worktree"),
            rel("worker-a", "worker"),
            rel("receipt-2", "receipt")
          ]
        }
      ],
      "ocel:objects" => [
        %{"id" => "run-1", "type" => "Run", "attributes" => %{}, "relationships" => []},
        # Object-to-object relationships (Epoch -> Run, Worker -> Epoch,
        # Receipt -> Epoch) are real OcelEgress facts that must NOT enter
        # the event-to-object link set -- the golden expectations below
        # prove their exclusion.
        %{
          "id" => "epoch-1",
          "type" => "Epoch",
          "attributes" => %{},
          "relationships" => [rel("run-1", "run")]
        },
        %{
          "id" => "epoch-2",
          "type" => "Epoch",
          "attributes" => %{},
          "relationships" => [rel("run-1", "run")]
        },
        %{
          "id" => "worker-a",
          "type" => "Worker",
          "attributes" => %{},
          "relationships" => [rel("epoch-1", "epoch")]
        },
        %{
          "id" => "receipt-1",
          "type" => "Receipt",
          "attributes" => %{},
          "relationships" => [rel("epoch-1", "epoch")]
        },
        %{
          "id" => "receipt-2",
          "type" => "Receipt",
          "attributes" => %{},
          "relationships" => [rel("epoch-1", "epoch")]
        },
        %{"id" => "/wt/demo", "type" => "Worktree", "attributes" => %{}, "relationships" => []}
      ]
    }
  end

  defp rel(object_id, qualifier), do: %{"objectId" => object_id, "qualifier" => qualifier}

  # Hand-computed from the 11 events above: the four distinct co-occurring
  # object-type sets and how many events exhibit each (sum = 11).
  defp golden_interactions do
    %{
      ["Epoch", "Receipt", "Run", "Worker", "Worktree"] => 4,
      ["Epoch", "Run", "Worker", "Worktree"] => 2,
      ["Epoch", "Run", "Worktree"] => 4,
      ["Run"] => 1
    }
  end

  # Hand-computed per {object_type, event_type} over distinct events.
  # Every event references the Run; all but run_started reference an Epoch;
  # all but run_started reference the Worktree; the Worker appears on
  # epoch_claimed/epoch_completed/receipt_closed/heartbeat_recorded/
  # verification_passed/refused; the Receipts on the last four.
  defp golden_frequency do
    %{
      {"Epoch", "epoch_claimed"} => 1,
      {"Epoch", "epoch_completed"} => 1,
      {"Epoch", "epoch_missed"} => 1,
      {"Epoch", "epoch_scheduled"} => 2,
      {"Epoch", "epoch_started"} => 1,
      {"Epoch", "heartbeat_recorded"} => 1,
      {"Epoch", "receipt_closed"} => 1,
      {"Epoch", "refused"} => 1,
      {"Epoch", "verification_passed"} => 1,
      {"Receipt", "heartbeat_recorded"} => 1,
      {"Receipt", "receipt_closed"} => 1,
      {"Receipt", "refused"} => 1,
      {"Receipt", "verification_passed"} => 1,
      {"Run", "epoch_claimed"} => 1,
      {"Run", "epoch_completed"} => 1,
      {"Run", "epoch_missed"} => 1,
      {"Run", "epoch_scheduled"} => 2,
      {"Run", "epoch_started"} => 1,
      {"Run", "heartbeat_recorded"} => 1,
      {"Run", "receipt_closed"} => 1,
      {"Run", "refused"} => 1,
      {"Run", "run_started"} => 1,
      {"Run", "verification_passed"} => 1,
      {"Worktree", "epoch_claimed"} => 1,
      {"Worktree", "epoch_completed"} => 1,
      {"Worktree", "epoch_missed"} => 1,
      {"Worktree", "epoch_scheduled"} => 2,
      {"Worktree", "epoch_started"} => 1,
      {"Worktree", "heartbeat_recorded"} => 1,
      {"Worktree", "receipt_closed"} => 1,
      {"Worktree", "refused"} => 1,
      {"Worktree", "verification_passed"} => 1,
      {"Worker", "epoch_claimed"} => 1,
      {"Worker", "epoch_completed"} => 1,
      {"Worker", "heartbeat_recorded"} => 1,
      {"Worker", "receipt_closed"} => 1,
      {"Worker", "refused"} => 1,
      {"Worker", "verification_passed"} => 1
    }
  end

  # --------------------------------------------------------------------------------
  # Golden exact-map assertions (the falsifier run)
  # --------------------------------------------------------------------------------

  test "object_type_interactions/1 on the golden doc equals the hand-computed map" do
    assert Ocpm.object_type_interactions(golden_document()) == golden_interactions()
  end

  test "object_type_activity_frequency/1 on the golden doc equals the hand-computed map" do
    assert Ocpm.object_type_activity_frequency(golden_document()) == golden_frequency()
  end

  test "report/1 projects both primitives into sorted JSON-encodable entries" do
    report = Ocpm.report(golden_document())

    assert report["object_type_interactions"] == [
             %{
               "count" => 4,
               "types" => ["Epoch", "Receipt", "Run", "Worker", "Worktree"]
             },
             %{"count" => 2, "types" => ["Epoch", "Run", "Worker", "Worktree"]},
             %{"count" => 4, "types" => ["Epoch", "Run", "Worktree"]},
             %{"count" => 1, "types" => ["Run"]}
           ]

    assert report["object_type_activity_frequency"] ==
             golden_frequency()
             |> Enum.map(fn {{object_type, event_type}, count} ->
               %{
                 "object_type" => object_type,
                 "event_type" => event_type,
                 "count" => count
               }
             end)
             |> Enum.sort_by(&{&1["object_type"], &1["event_type"]})

    # The report must survive a real JSON round-trip (tuple keys cannot).
    assert {:ok, decoded} = JSON.decode(JSON.encode!(report))
    assert decoded == report
  end

  # --------------------------------------------------------------------------------
  # Link-list kernels (the beam4pm reference arities)
  # --------------------------------------------------------------------------------

  test "object_type_interactions/2 kernel over raw links and objects" do
    links = [{"e1", "o1"}, {"e1", "o2"}, {"e2", "o1"}, {"e3", "ghost"}]

    objects = [
      %{object_id: "o1", object_type: "order"},
      %{object_id: "o2", object_type: "item"}
    ]

    assert Ocpm.object_type_interactions(links, objects) == %{
             ["item", "order"] => 1,
             ["order"] => 1
           }
  end

  test "object_type_activity_frequency/3 kernel over raw links, events and objects" do
    links = [{"e1", "o1"}, {"e1", "o2"}, {"e2", "o1"}]

    events = [
      %{event_id: "e1", event_type: "place"},
      %{event_id: "e2", event_type: "ship"}
    ]

    objects = [
      %{object_id: "o1", object_type: "order"},
      %{object_id: "o2", object_type: "item"}
    ]

    assert Ocpm.object_type_activity_frequency(links, events, objects) == %{
             {"item", "place"} => 1,
             {"order", "place"} => 1,
             {"order", "ship"} => 1
           }
  end

  # --------------------------------------------------------------------------------
  # Edge laws
  # --------------------------------------------------------------------------------

  test "a relationship to an undeclared object contributes nothing (no empty-set bucket, no nil type)" do
    document = %{
      "ocel:objectTypes" => [%{"name" => "Run"}],
      "ocel:eventTypes" => [%{"name" => "run_started"}],
      "ocel:events" => [
        %{
          "id" => "run_started:run-1",
          "type" => "run_started",
          "time" => "2026-09-30T09:00:00Z",
          "attributes" => %{},
          "relationships" => [rel("ghost-object", "run")]
        }
      ],
      "ocel:objects" => []
    }

    assert Ocpm.object_type_interactions(document) == %{}
    assert Ocpm.object_type_activity_frequency(document) == %{}
  end

  test "duplicate relationships to the same object within one event count once" do
    document = %{
      "ocel:objectTypes" => [%{"name" => "Run"}],
      "ocel:eventTypes" => [%{"name" => "run_started"}],
      "ocel:events" => [
        %{
          "id" => "run_started:run-1",
          "type" => "run_started",
          "time" => "2026-09-30T09:00:00Z",
          "attributes" => %{},
          "relationships" => [rel("run-1", "run"), rel("run-1", "run")]
        }
      ],
      "ocel:objects" => [%{"id" => "run-1", "type" => "Run", "attributes" => %{}, "relationships" => []}]
    }

    assert Ocpm.object_type_interactions(document) == %{["Run"] => 1}

    assert Ocpm.object_type_activity_frequency(document) == %{
             {"Run", "run_started"} => 1
           }
  end

  test "an empty OCEL document yields empty maps" do
    document = %{
      "ocel:objectTypes" => [],
      "ocel:eventTypes" => [],
      "ocel:events" => [],
      "ocel:objects" => []
    }

    assert Ocpm.object_type_interactions(document) == %{}
    assert Ocpm.object_type_activity_frequency(document) == %{}
  end

  test "the honest gap list is pinned (no object-centric Petri net synthesis)" do
    assert :object_centric_petri_net_synthesis in Ocpm.gaps()
  end

  # --------------------------------------------------------------------------------
  # Real subprocess qualification of mix xaas.ocel.ocpm
  # --------------------------------------------------------------------------------

  @tag :subprocess
  test "mix xaas.ocel.ocpm exits 0 and prints the golden report as JSON" do
    path = write_tmp("golden.ocel.json", JSON.encode!(golden_document()))

    {output, 0} = run_task([path])

    json_line =
      output
      |> String.split("\n")
      # Mix may replay unrelated compiler diagnostics from OTHER files on
      # the base head; the task's own output is the JSON object line.
      |> Enum.find(&String.starts_with?(&1, "{"))

    assert json_line
    assert {:ok, decoded} = JSON.decode(json_line)
    assert decoded == Ocpm.report(golden_document())
  end

  @tag :subprocess
  test "mix xaas.ocel.ocpm exits 1 on a missing file" do
    {output, 1} = run_task(["/nonexistent/xa3009_ocpm_missing.ocel.json"])
    assert output =~ "cannot read file"
  end

  @tag :subprocess
  test "mix xaas.ocel.ocpm exits 1 on bad usage (no path)" do
    {output, 1} = run_task([])
    assert output =~ "usage: mix xaas.ocel.ocpm <path.ocel.json>"
  end

  defp run_task(args) do
    System.cmd("mix", ["xaas.ocel.ocpm" | args],
      cd: File.cwd!(),
      env: %{"MIX_ENV" => "test"},
      stderr_to_stdout: true
    )
  end

  defp write_tmp(name, body) do
    path =
      Path.join(
        System.tmp_dir!(),
        "xa3009_ocpm_#{System.unique_integer([:positive])}_#{name}"
      )

    File.write!(path, body)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
