defmodule Xaas.Ultracode.CapitalCensus.SelfDigestWorkerTest do
  @moduledoc """
  Chicago qualification of the self-digest PRODUCTION caller
  (`Xaas.Ultracode.SelfDigestWorker`): a real telemetry NDJSON fixture on
  disk, real `SelfDigest.Run.digest/1`, real generated Ash resources on
  sandboxed Postgres. Falsifiers:

    1. a recurring (>= threshold) classified frontier cluster MUST persist
       exactly one OPEN WorkOrder whose subject is UltraCode itself, chained
       to a Gap(:hypothesis) and ExperienceCluster;
    2. a second run over the same window MUST NOT duplicate it (dedup);
    3. a recurring UNCLASSIFIED shape MUST NOT persist an order -- it is a
       receipted candidate only (unknown never guesses);
    4. an unconfigured telemetry path is a typed refusal.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Ultracode.CapitalCensus.{Gap, WorkOrder}
  alias Xaas.Ultracode.CapitalCensus.SelfDigest.Run, as: SelfDigest
  alias Xaas.Ultracode.SelfDigestWorker

  setup do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)

    tmp = Path.join(System.tmp_dir!(), "self-digest-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    %{tmp: tmp}
  end

  defp write_telemetry!(tmp, entries) do
    path = Path.join(tmp, "loop.ndjson")
    now = DateTime.utc_now()

    lines =
      entries
      |> Enum.with_index()
      |> Enum.map(fn {entry, i} ->
        ts = DateTime.add(now, -(i + 1) * 60, :second) |> DateTime.to_iso8601()
        Jason.encode!(Map.put(entry, "ts", ts)) <> "\n"
      end)

    File.write!(path, lines)
    path
  end

  defp recurring_classified(n) do
    for i <- 1..n,
        do: %{
          "kind" => "ultracode-wave-loop/1",
          "tick" => i,
          "outcome" => "blocked",
          "step" => "dispatch",
          "residual_shape" => "toolchain_pin_missing"
        }
  end

  defp self_orders do
    WorkOrder
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&(&1.subject == SelfDigest.self_subject()))
  end

  test "a recurring classified cluster creates ONE self-work order; rerun dedups", %{tmp: tmp} do
    path =
      write_telemetry!(
        tmp,
        recurring_classified(3) ++
          [%{"kind" => "ultracode-wave-loop/1", "outcome" => "complete", "step" => nil}]
      )

    job = %Oban.Job{args: %{"telemetry_path" => path, "out_dir" => Path.join(tmp, "out")}}

    assert :ok = SelfDigestWorker.perform(job)

    assert [order] = self_orders()
    assert order.subject == "ultracode-self-digest"
    assert order.status == :open
    assert order.classification == :runtime
    assert order.derived_from_receipt =~ "self-digest:sha256:"
    assert order.falsifier =~ path

    gap = Ash.get!(Gap, order.gap_id, authorize?: false)
    assert gap.status == :hypothesis
    assert gap.residual_shape == "toolchain_pin_missing"
    assert gap.context == "dispatch"
    assert gap.episode_count == 3

    receipt =
      Path.join([tmp, "out", "self-digest-receipt.json"]) |> File.read!() |> Jason.decode!()

    assert receipt["schema"] == "xaas.self-digest-receipt/1"
    assert [%{"created" => true, "id" => id}] = receipt["created_work_orders"]
    assert id == order.id

    # Falsifier 2: same window again => the open order owns the topology.
    assert :ok = SelfDigestWorker.perform(job)

    assert [again] = self_orders()
    assert again.id == order.id
  end

  test "a recurring UNCLASSIFIED shape is a receipted candidate, never an order", %{tmp: tmp} do
    entries =
      for i <- 1..3,
          do: %{
            "kind" => "ultracode-wave-loop/1",
            "tick" => i,
            "outcome" => "blocked",
            "step" => "3"
          }

    path = write_telemetry!(tmp, entries)

    assert {:ok, summary} =
             SelfDigestWorker.run(%{"telemetry_path" => path, "out_dir" => Path.join(tmp, "out")})

    assert self_orders() == []
    assert [%{"refused" => "unknown_class", "count" => 3}] = summary["candidates"]
    assert summary["created_work_orders"] == []
  end

  test "below threshold (2 episodes) creates nothing", %{tmp: tmp} do
    path = write_telemetry!(tmp, recurring_classified(2))

    assert {:ok, summary} =
             SelfDigestWorker.run(%{"telemetry_path" => path, "out_dir" => Path.join(tmp, "out")})

    assert summary["recurring_clusters"] == []
    assert self_orders() == []
  end

  test "unconfigured / unreadable telemetry is a typed refusal", %{tmp: tmp} do
    saved = Application.fetch_env(:xaas, :ultracode_wave_loop_telemetry_path)
    Application.delete_env(:xaas, :ultracode_wave_loop_telemetry_path)

    try do
      assert {:error, {:self_digest_unconfigured, :telemetry_path}} = SelfDigestWorker.run(%{})
    after
      case saved do
        {:ok, v} -> Application.put_env(:xaas, :ultracode_wave_loop_telemetry_path, v)
        :error -> :ok
      end
    end

    assert {:error, {:telemetry_unreadable, _, :enoent}} =
             SelfDigestWorker.run(%{
               "telemetry_path" => Path.join(tmp, "absent.ndjson"),
               "out_dir" => tmp
             })
  end
end
