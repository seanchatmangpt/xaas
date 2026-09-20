defmodule Xaas.Ultracode.SemanticWave do
  @moduledoc """
  Dispatch controller for already-admitted semantic work whose explicit
  execution policy is :autonomic_wave_attempt.

  This module does not select the semantic frontier, create work orders, grant
  leases, verify outcomes, or promote standing. Those boundaries remain with
  the canonical graph producer, SemanticWork materialization, Lease, Verifier,
  and terminal receipts respectively.

  The controller only discovers ready materialized Epochs and invokes the fixed
  directed dispatcher concurrently. The worker must still win the real atomic
  Lease claim for the exact Epoch.
  """

  require Ash.Query

  alias Xaas.Ultracode.Epoch

  @default_capacity 5
  @default_max_items 50

  @spec run(keyword()) :: {:ok, map()} | {:error, term()}
  def run(opts \\ []) do
    capacity = Keyword.get(opts, :capacity, @default_capacity)
    max_items = Keyword.get(opts, :max_items, @default_max_items)
    worker = Keyword.get(opts, :worker, &dispatch_worker/2)
    state_dir = Keyword.get(opts, :state_dir, default_state_dir())
    project_root = Keyword.get(opts, :project_root, File.cwd!())

    with :ok <- admit_positive(:capacity, capacity),
         :ok <- admit_positive(:max_items, max_items),
         {:ok, epochs} <- ready_epochs(max_items) do
      File.mkdir_p!(state_dir)

      ctx = %{
        capacity: capacity,
        worker: worker,
        state_dir: state_dir,
        project_root: project_root
      }

      results =
        epochs
        |> Task.async_stream(&dispatch(&1, ctx),
          max_concurrency: capacity,
          ordered: true,
          timeout: :infinity
        )
        |> Enum.zip(epochs)
        |> Enum.map(fn
          {{:ok, result}, _epoch} -> result
          {{:exit, reason}, epoch} -> result(epoch, :error, {:task_exit, reason})
        end)

      report = %{
        "schema" => "xaas.semantic-wave-dispatch-receipt/1",
        "status" => wave_status(epochs, results),
        "capacity" => capacity,
        "sensed" => length(epochs),
        "dispatched" => Enum.count(results, &(&1.status == :dispatched)),
        "items" =>
          Enum.map(results, fn item ->
            %{
              "epoch_id" => item.epoch_id,
              "run_id" => item.run_id,
              "work_order_iri" => item.work_order_iri,
              "checkpoint_iri" => item.checkpoint_iri,
              "graph_digest" => item.graph_digest,
              "status" => Atom.to_string(item.status),
              "detail" => inspect(item.detail)
            }
          end),
        "non_claims" => [
          "Dispatch is not Lease admission.",
          "Dispatch is not verifier success.",
          "Dispatch does not promote semantic standing.",
          "No merge, publication, or deployment authority is created."
        ]
      }

      path =
        Path.join(
          state_dir,
          "semantic-wave-#{System.unique_integer([:positive, :monotonic])}.json"
        )

      File.write!(path, Jason.encode!(report, pretty: true))
      {:ok, Map.put(report, "receipt_path", path)}
    end
  end

  @doc false
  @spec ready_epochs(pos_integer()) :: {:ok, [Epoch.t()]} | {:error, term()}
  def ready_epochs(limit \\ @default_max_items) when is_integer(limit) and limit > 0 do
    now = DateTime.utc_now()

    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(state == :running)
    |> Ash.Query.filter(run.execution_policy == :autonomic_wave_attempt)
    |> Ash.Query.filter(is_nil(lease_token) or lease_expires_at < ^now)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.Query.limit(limit)
    |> Ash.read(load: [:run], authorize?: false)
  end

  defp dispatch(%Epoch{} = epoch, ctx) do
    case ctx.worker.(epoch, ctx) do
      :ok -> result(epoch, :dispatched, :ok)
      {:ok, detail} -> result(epoch, :dispatched, detail)
      :rate_limited -> result(epoch, :rate_limited, :rate_limited)
      {:error, reason} -> result(epoch, :error, reason)
      other -> result(epoch, :error, {:unexpected_worker_result, other})
    end
  rescue
    error -> result(epoch, :error, {:worker_crashed, Exception.message(error)})
  end

  defp result(%Epoch{} = epoch, status, detail) do
    run = epoch.run

    %{
      epoch_id: epoch.id,
      run_id: epoch.run_id,
      work_order_iri: run && run.work_order_iri,
      checkpoint_iri: run && run.checkpoint_iri,
      graph_digest: run && run.graph_digest,
      status: status,
      detail: detail
    }
  end

  defp dispatch_worker(%Epoch{} = epoch, ctx) do
    script = Path.join(ctx.project_root, "scripts/xaas-glm-failover-dispatcher.sh")

    case System.cmd("bash", [script, "--epoch", epoch.id],
           env: [{"STATE_DIR", ctx.state_dir}],
           stderr_to_stdout: true
         ) do
      {_out, 0} -> :ok
      {_out, 75} -> :rate_limited
      {out, code} -> {:error, {:dispatcher_exit, code, String.slice(out, -300, 300)}}
    end
  end

  defp wave_status([], _results), do: "IDLE"

  defp wave_status(_epochs, results) do
    cond do
      Enum.all?(results, &(&1.status == :dispatched)) -> "DISPATCHED"
      Enum.any?(results, &(&1.status == :dispatched)) -> "PARTIAL"
      true -> "BLOCKED"
    end
  end

  defp admit_positive(_name, value) when is_integer(value) and value > 0, do: :ok
  defp admit_positive(name, value), do: {:error, {:invalid_wave_option, name, value}}

  defp default_state_dir do
    Application.get_env(
      :xaas,
      :ultracode_semantic_wave_state_dir,
      Path.expand("~/.xaas/semantic-wave")
    )
  end
end
