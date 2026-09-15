defmodule Xaas.Ultracode.Reactor do
  @moduledoc """
  The Ultracode engineering-workflow Reactor.

  This is the seam `Xaas.Ultracode.Run`'s AshOban `:tick` scheduled action
  calls into (per the repo's existing Reactor-as-DO-kernel convention,
  `lib/xaas/actuation.ex`). The scheduler owns ONLY Time -> Tick -- it
  contains no engineering-workflow logic itself (see the `:tick` action in
  `Xaas.Ultracode.Run`, which does nothing but invoke this Reactor).

  Three real steps: `:advance_missed_epochs` (missed-epoch detection via
  `Xaas.Ultracode.MissedEpochs.advance_all/0`), `:run_active_epochs`, which
  -- for every `:running` `Run`'s current active `Epoch` (an `:expected` or
  `:running` epoch, one per Run per this repo's `AtMostOneActiveEpoch`
  invariant) -- invokes the full `Xaas.Ultracode.EpochReactor` DAG (Observe
  -> Admit -> Plan -> Construct -> Verify -> Receipt), and
  `:advance_next_epochs` (`Xaas.Ultracode.NextEpoch.advance_all/0`), which
  closes ULTRACODE-50 blocker (1): once a Run's active epoch reaches
  `:completed`, this step constructs `Epoch{cycle: N+1}` (or transitions the
  Run itself to `:completed` at `max_cycles`) -- without it, a Run silently
  stalled forever after its first epoch completed even though `:tick` kept
  firing every minute. `:run_active_epochs` depends on
  `:advance_missed_epochs`'s result so missed-epoch detection always runs
  first within the same tick; `:advance_next_epochs` depends on
  `:run_active_epochs`'s result so a next epoch is only constructed after
  this same tick's epoch-DAG execution has had the chance to complete the
  current one (an epoch that transitions to `:completed` on THIS tick
  becomes eligible for its successor on the NEXT tick, one real Oban cron
  firing later, not synchronously within the same tick -- see
  `docs/ultracode/PROGRESS.md` for why that's the correct evidentiary
  boundary between "this epoch finished" and "the next epoch started").
  """

  use Reactor

  require Ash.Query

  step :advance_missed_epochs do
    run(fn _arguments, _context ->
      {:ok, Xaas.Ultracode.MissedEpochs.advance_all()}
    end)
  end

  step :run_active_epochs do
    wait_for(:advance_missed_epochs)

    run(fn _arguments, _context ->
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
    end)
  end

  step :advance_next_epochs do
    wait_for(:run_active_epochs)

    run(fn _arguments, _context ->
      {:ok, Xaas.Ultracode.NextEpoch.advance_all()}
    end)
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
