defmodule Xaas.Ultracode.Reactor do
  @moduledoc """
  The Ultracode engineering-workflow Reactor.

  This is the seam `Xaas.Ultracode.Run`'s AshOban `:tick` scheduled action
  calls into (per the repo's existing Reactor-as-DO-kernel convention,
  `lib/xaas/actuation.ex`). The scheduler owns ONLY Time -> Tick -- it
  contains no engineering-workflow logic itself (see the `:tick` action in
  `Xaas.Ultracode.Run`, which does nothing but invoke this Reactor).

  Two real steps: `:advance_missed_epochs` (unchanged -- missed-epoch
  detection via `Xaas.Ultracode.MissedEpochs.advance_all/0`) and
  `:run_active_epochs`, which -- for every `:running` `Run`'s current
  active `Epoch` (an `:expected` or `:running` epoch, one per Run per this
  repo's `AtMostOneActiveEpoch` invariant) -- invokes the full
  `Xaas.Ultracode.EpochReactor` DAG (Observe -> Admit -> Plan -> Construct
  -> Verify -> Receipt). `:run_active_epochs` depends on
  `:advance_missed_epochs`'s result so missed-epoch detection always runs
  first within the same tick, keeping a Run's active-epoch selection
  consistent with epochs just marked `:missed` this same cycle.
  """

  use Reactor

  require Ash.Query

  step :advance_missed_epochs do
    run fn _arguments, _context ->
      {:ok, Xaas.Ultracode.MissedEpochs.advance_all()}
    end
  end

  step :run_active_epochs do
    argument(:missed_summary, result(:advance_missed_epochs))

    run fn _arguments, _context ->
      {:ok, active_runs} =
        Xaas.Ultracode.Run
        |> Ash.Query.filter(state == :running)
        |> Ash.read(authorize?: false)

      results =
        active_runs
        |> Enum.map(&active_epoch_id/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn epoch_id ->
          case Reactor.run(Xaas.Ultracode.EpochReactor, %{epoch_id: epoch_id}) do
            {:ok, receipt_summary} -> receipt_summary
            {:error, reason} -> %{epoch_id: epoch_id, outcome: :refused, error: reason}
          end
        end)

      {:ok, results}
    end
  end

  defp active_epoch_id(%Xaas.Ultracode.Run{id: run_id}) do
    Xaas.Ultracode.Epoch
    |> Ash.Query.filter(run_id == ^run_id)
    |> Ash.Query.filter(state in [:expected, :running])
    |> Ash.Query.sort(cycle: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> case do
      [epoch] -> epoch.id
      [] -> nil
    end
  end
end
