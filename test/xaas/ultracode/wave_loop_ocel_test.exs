defmodule Xaas.Ultracode.WaveLoopOcelTest do
  use Xaas.DataCase, async: false

  @moduledoc """
  OCEL 2.0 evidence for WaveLoop ticks (`Xaas.Ultracode.WaveLoop.Ocel`).

  Chicago-style: REAL `WaveLoop.tick/1` against REAL Postgres rows
  (Run/Epoch/Lease/Receipt via the sandbox), REAL files on disk, the REAL
  existing OCEL 2.0 court (`Xaas.Ultracode.Ocel.Validator`), and a REAL
  `:telemetry` handler observing the emission counter. The dispatcher seam
  is the same hermetic stand-in `WaveLoopTest` uses (a function that closes
  the epoch like a fabric worker, or kills its own task) -- not a mock of
  any owned collaborator; nothing asserts on calls.
  """

  alias Xaas.Ultracode.{Epoch, Receipt, RecoveryPolicy, Run}
  alias Xaas.Ultracode.Ocel.Validator
  alias Xaas.Ultracode.WaveLoop
  alias Xaas.Ultracode.WaveLoop.Ocel

  @state """
  ### [3] Branch integrations
  - **description:** integrate.

  | step | status | evidence |
  |---|---|---|
  | 3 branch integrations | PENDING | none yet |

  REMAINING: step 3. Then COMPLETE.
  """

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    prior = Application.get_env(:xaas, :ultracode_wave_loop_ocel_path)
    Application.delete_env(:xaas, :ultracode_wave_loop_ocel_path)

    on_exit(fn ->
      if prior,
        do: Application.put_env(:xaas, :ultracode_wave_loop_ocel_path, prior),
        else: Application.delete_env(:xaas, :ultracode_wave_loop_ocel_path)
    end)

    dir =
      Path.join(
        System.tmp_dir!(),
        "wave-loop-ocel-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    state_path = Path.join(dir, "STATE.md")
    File.write!(state_path, @state)

    handler = "wave-loop-ocel-test-#{System.unique_integer([:positive])}"
    test_pid = self()

    :ok =
      :telemetry.attach(
        handler,
        Ocel.telemetry_event(),
        fn _event, measurements, metadata, _ ->
          send(test_pid, {:ocel_emit, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    %{state_path: state_path, telemetry_path: Path.join(dir, "loop.ndjson")}
  end

  test "a worker_completed tick emits one validated OCEL event with step/epoch/run/receipt/provider",
       %{state_path: state_path, telemetry_path: telemetry_path} do
    assert {:ok, %{outcome: :worker_completed, step: "3", receipt: detail}} =
             WaveLoop.tick(
               state_path: state_path,
               telemetry_path: telemetry_path,
               dispatcher: closing_dispatch()
             )

    ocel_path = Ocel.ocel_path(telemetry_path)
    assert ocel_path == Path.rootname(telemetry_path) <> ".ocel.ndjson"
    assert_received {:ocel_emit, %{count: 1}, %{status: :ok, path: ^ocel_path}}

    [doc] = ocel_docs(ocel_path)
    assert {:ok, %{"status" => "valid", "event_count" => 1}} = Validator.validate(doc)

    [event] = doc["ocel:events"]
    assert event["type"] == "wave-loop:worker_completed"
    assert event["attributes"]["tick"] == 1
    assert event["attributes"]["step"] == "3"
    assert event["attributes"]["policy_digest"] == RecoveryPolicy.receipt().policy_digest

    assert event["attributes"]["policy_decision"] ==
             Atom.to_string(RecoveryPolicy.decide(:worker_completed, false))

    assert event["attributes"]["provider_breaker"] == "closed"

    epoch = Ash.get!(Epoch, detail.epoch_id, action: :read_unscoped, authorize?: false)
    [receipt] = sealed_receipts(epoch.id)

    assert relations(event) == %{
             "wave-loop:step-3" => "wavestep",
             epoch.id => "epoch",
             epoch.run_id => "run",
             receipt.id => "receipt",
             "zcode" => "provider"
           }

    assert types(doc) == %{
             "wave-loop:step-3" => "WaveStep",
             epoch.id => "Epoch",
             epoch.run_id => "Run",
             receipt.id => "Receipt",
             "zcode" => "Provider"
           }
  end

  test "a killed dispatch task (requeued) emits a validated event relating the reclaim receipt",
       %{state_path: state_path, telemetry_path: telemetry_path} do
    killer = fn _epoch_id, _opts -> Process.exit(self(), :kill) end

    assert {:ok, %{outcome: :requeued, step: "3", receipt: detail}} =
             WaveLoop.tick(
               state_path: state_path,
               telemetry_path: telemetry_path,
               dispatcher: killer
             )

    assert is_binary(detail.reclaim_receipt_id)

    [doc] = ocel_docs(Ocel.ocel_path(telemetry_path))
    assert {:ok, %{"status" => "valid"}} = Validator.validate(doc)

    [event] = doc["ocel:events"]
    assert event["type"] == "wave-loop:requeued"
    assert event["attributes"]["policy_digest"] == RecoveryPolicy.receipt().policy_digest

    assert event["attributes"]["policy_decision"] ==
             Atom.to_string(RecoveryPolicy.decide(:requeued, false))

    epoch = Ash.get!(Epoch, detail.epoch_id, action: :read_unscoped, authorize?: false)
    assert epoch.state == :failed

    reclaim = Ash.get!(Receipt, detail.reclaim_receipt_id, authorize?: false)
    assert reclaim.epoch_id == epoch.id

    assert relations(event) == %{
             "wave-loop:step-3" => "wavestep",
             epoch.id => "epoch",
             epoch.run_id => "run",
             reclaim.id => "receipt",
             "zcode" => "provider"
           }

    # Object-to-object: the receipt belongs to the epoch, the epoch to its run.
    objects = Map.new(doc["ocel:objects"], &{&1["id"], &1})

    assert objects[reclaim.id]["relationships"] == [
             %{"objectId" => epoch.id, "qualifier" => "epoch"}
           ]

    assert objects[epoch.id]["relationships"] == [
             %{"objectId" => epoch.run_id, "qualifier" => "run"}
           ]

    assert %Run{} = Ash.get!(Run, epoch.run_id, action: :read_unscoped, authorize?: false)
  end

  test "an unwritable OCEL path never changes the tick outcome, and the failure is counted",
       %{state_path: state_path, telemetry_path: telemetry_path} do
    # /dev/null is a character device: mkdir_p beneath it fails for real.
    Application.put_env(:xaas, :ultracode_wave_loop_ocel_path, "/dev/null/nope/loop.ocel.ndjson")

    assert {:ok, %{outcome: :worker_completed, step: "3"}} =
             WaveLoop.tick(
               state_path: state_path,
               telemetry_path: telemetry_path,
               dispatcher: closing_dispatch()
             )

    assert_received {:ocel_emit, %{count: 1}, %{status: :error, reason: {:ocel_write, _, _}}}
    # The telemetry ledger still recorded the tick.
    assert File.read!(telemetry_path) =~ ~s("outcome":"worker_completed")
  end

  test "a document the court refuses is never written (validation gates the sink)" do
    doc =
      Ocel.build_document(%{
        tick: 1,
        step: "3",
        outcome: :requeued,
        outcome_name: "requeued",
        time: "not-a-time",
        detail: %{},
        provider: "zcode"
      })

    assert {:error, {:ocel_invalid, [%{path: "ocel:events[0].time"}]}} = Ocel.validate(doc)
  end

  # ------------------------------------------------------------------

  defp ocel_docs(path) do
    path |> File.read!() |> String.split("\n", trim: true) |> Enum.map(&JSON.decode!/1)
  end

  defp relations(event), do: Map.new(event["relationships"], &{&1["objectId"], &1["qualifier"]})
  defp types(doc), do: Map.new(doc["ocel:objects"], &{&1["id"], &1["type"]})

  defp sealed_receipts(epoch_id) do
    Receipt
    |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
    |> Ash.read!(authorize?: false)
  end

  defp closing_dispatch do
    fn epoch_id, _opts ->
      {:ok, epoch} = Ash.get(Epoch, epoch_id, action: :read_unscoped, authorize?: false)

      {:ok, _} =
        epoch
        |> Ash.Changeset.for_update(
          :complete,
          %{final_head: "sha256:" <> String.duplicate("c", 64)},
          authorize?: false
        )
        |> Ash.update()

      {:ok, _} =
        Receipt
        |> Ash.Changeset.for_create(
          :seal,
          %{
            epoch_id: epoch_id,
            subject: epoch.exact_subject,
            outcome: :partial_alive,
            evidence: %{"head_verified" => true, "note" => "ocel test worker closed"}
          },
          authorize?: false
        )
        |> Ash.create()

      {:ok,
       %{
         status: :ok,
         epoch_id: epoch_id,
         worker_id: "zcode-test",
         mode: :reap,
         protocol: :xaas_prompt,
         attempts: 1,
         exit_code: 0,
         duration_ms: 5,
         output_tail: "closed",
         log_path: "/tmp/unused.log",
         prompt: nil,
         epoch_state: :completed,
         receipts: [%{"outcome" => "partial_alive", "head_verified" => true}]
       }}
    end
  end
end
