defmodule Xaas.Ultracode.ClosureController do
  @moduledoc """
  Manufactures the Run-level continue/suspend/close decision from persisted
  frontier evidence.

  Epoch completion is never Run completion. Exhausting max_cycles is a bounded
  scheduling fact: with an open or unknown frontier the Run is suspended, not
  completed. Only a persisted, digest-bound empty frontier may close the Run.
  """

  require Ash.Query

  alias Xaas.Ultracode.{Epoch, Frontier, Run}

  @actor_service :ultracode_reactor

  @spec record(Run.t(), map()) ::
          {:ok, %{run: Run.t(), frontier: map()}} | {:error, term()}
  def record(%Run{} = run, facts) do
    with {:ok, snapshot} <- Frontier.admit(facts),
         {:ok, updated} <-
           run
           |> Ash.Changeset.for_update(
             :record_frontier,
             %{
               frontier: Map.drop(snapshot, ["digest"]),
               frontier_digest: snapshot["digest"],
               frontier_size: snapshot["pending_work"],
               frontier_recorded_at: DateTime.utc_now()
             },
             authorize?: false
           )
           |> Ash.update(actor: actor()) do
      {:ok, %{run: updated, frontier: snapshot}}
    end
  end

  @doc """
  Reconcile a Run that has reached its cycle budget.

  * persisted empty frontier -> :completed/:admitted
  * persisted open frontier -> :suspended/:unknown
  * no/corrupt frontier -> :suspended/:unknown

  The result is a typed runtime decision; it does not grant execution authority.
  """
  @spec reconcile_cycle_exhausted(Run.t()) :: {:ok, map()} | {:error, term()}
  def reconcile_cycle_exhausted(%Run{id: id}) do
    with {:ok, %Run{} = run} <- Ash.get(Run, id, action: :read_unscoped, authorize?: false) do
      case Frontier.from_run(run) do
        {:ok, frontier} ->
          active_epochs = active_epoch_count(run.id)

          if closure_proved?(frontier, active_epochs) do
            close(run, frontier)
          else
            suspend(run, frontier, {:frontier_open, active_epochs})
          end

        {:error, reason} ->
          suspend(run, nil, reason)
      end
    end
  end

  @spec resume(Run.t(), pos_integer()) :: {:ok, Run.t()} | {:error, term()}
  def resume(%Run{} = run, additional_cycles \\ 1)
      when is_integer(additional_cycles) and additional_cycles > 0 do
    run
    |> Ash.Changeset.for_update(
      :resume_frontier,
      %{additional_cycles: additional_cycles},
      authorize?: false
    )
    |> Ash.update(actor: actor())
  end

  @doc """
  Record the closure fact for a completed WaveLoop step. The worker does not
  write scheduler state; the fabric derives this from its own completed epoch.
  """
  @spec record_empty_for_epoch(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def record_empty_for_epoch(epoch_id, source \\ "wave_loop") do
    with {:ok, %Epoch{} = epoch} <-
           Ash.get(Epoch, epoch_id, action: :read_unscoped, authorize?: false),
         {:ok, %Run{} = run} <-
           Ash.get(Run, epoch.run_id, action: :read_unscoped, authorize?: false) do
      record(run, Frontier.empty(source))
    end
  end

  # Active epoch state is live database truth, not a worker-supplied
  # frontier assertion. A snapshot may have been recorded before the final
  # epoch settled; closure therefore joins the persisted semantic frontier
  # with the current Run/Epoch lifecycle.
  defp closure_proved?(frontier, active_epochs) do
    active_epochs == 0 and
      frontier["pending_work"] == 0 and
      frontier["unsettled_epochs"] == 0 and
      frontier["unpublished_deltas"] == 0 and
      frontier["unsatisfied_dependencies"] == 0
  end

  defp active_epoch_count(run_id) do
    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(run_id == ^run_id and state in [:expected, :running])
    |> Ash.read!(authorize?: false)
    |> length()
  end

  defp close(%Run{state: :completed} = run, frontier) do
    {:ok, report(:closed, run, frontier, :frontier_empty)}
  end

  defp close(%Run{} = run, frontier) when run.state in [:running, :suspended] do
    with {:ok, completed} <-
           run
           |> Ash.Changeset.for_update(
             :transition_state,
             %{state: :completed, standing: :admitted},
             authorize?: false
           )
           |> Ash.update(actor: actor()) do
      {:ok, report(:closed, completed, frontier, :frontier_empty)}
    end
  end

  defp close(%Run{} = run, _frontier),
    do: {:error, {:closure_state, run.state}}

  defp suspend(%Run{state: :suspended} = run, frontier, reason) do
    {:ok, report(:suspended, run, frontier, reason)}
  end

  defp suspend(%Run{state: :running} = run, frontier, reason) do
    with {:ok, suspended} <-
           run
           |> Ash.Changeset.for_update(
             :transition_state,
             %{state: :suspended, standing: :unknown},
             authorize?: false
           )
           |> Ash.update(actor: actor()) do
      {:ok, report(:suspended, suspended, frontier, reason)}
    end
  end

  defp suspend(%Run{} = run, _frontier, _reason),
    do: {:error, {:closure_state, run.state}}

  defp report(outcome, run, frontier, reason) do
    %{
      run: run,
      run_id: run.id,
      outcome: outcome,
      reason: reason,
      frontier_digest: frontier && frontier["digest"],
      frontier_size: frontier && frontier["pending_work"]
    }
  end

  defp actor, do: Xaas.SystemAuthority.new(@actor_service)
end
