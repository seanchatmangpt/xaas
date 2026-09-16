defmodule Xaas.Ultracode.Reactor do
  @moduledoc """
  The Ultracode engineering-workflow Reactor.

  This is the seam `Xaas.Ultracode.Run`'s AshOban `:tick` scheduled action
  calls into (per the repo's existing Reactor-as-DO-kernel convention,
  `lib/xaas/actuation.ex`). The scheduler owns ONLY Time -> Tick -- it
  contains no engineering-workflow logic itself (see the `:tick` action in
  `Xaas.Ultracode.Run`, which does nothing but invoke this Reactor).

  Four real steps. `:fetch_active_runs` reads every `:running` `Run` once;
  its result is threaded into the other three steps as a real, consumed
  argument (`active_runs`) so none of them re-scans the Run table
  independently -- per-tick query shape is `1 + up to 2N` (N = active Run
  count), down from `3 + up to 4N` before this was added (ERRC reduce:
  `Xaas.Ultracode.MissedEpochs.advance_all/1`,
  `Xaas.Ultracode.NextEpoch.advance_all/1`, and this Reactor's own
  `:run_active_epochs` step used to each independently query
  `Run |> filter(state == :running)`, and `NextEpoch.advance_run/1` used
  to issue two separate per-run queries where one now suffices -- named
  here as a known, bounded operational cost, matching this file's own
  practice of disclosing its design tradeoffs).

  `:advance_missed_epochs` (missed-epoch detection via
  `Xaas.Ultracode.MissedEpochs.advance_all/1`), `:run_active_epochs`, which
  -- for every `:running` `Run`'s current active `Epoch` (an `:expected` or
  `:running` epoch, one per Run per this repo's `AtMostOneActiveEpoch`
  invariant, loaded via the real `Run.active_epoch` relationship rather
  than a hand-rolled per-run query) -- invokes the full
  `Xaas.Ultracode.EpochReactor` DAG (Observe -> Admit -> Plan -> Construct
  -> Verify -> Receipt), and `:advance_next_epochs`
  (`Xaas.Ultracode.NextEpoch.advance_all/1`), which closes ULTRACODE-50
  blocker (1): once a Run's active epoch reaches `:completed`, this step
  constructs `Epoch{cycle: N+1}` (or transitions the Run itself to
  `:completed` at `max_cycles`) -- without it, a Run silently stalled
  forever after its first epoch completed even though `:tick` kept firing
  every minute.

  `:run_active_epochs` runs after `:advance_missed_epochs` (`wait_for`,
  not a fake data dependency -- see ERRC eliminate note below) so
  missed-epoch detection always happens first within the same tick;
  `:advance_next_epochs` runs after `:run_active_epochs` (`wait_for`) so a
  next epoch is only constructed after this same tick's epoch-DAG
  execution has had the chance to complete the current one (an epoch that
  transitions to `:completed` on THIS tick becomes eligible for its
  successor on the NEXT tick, one real Oban cron firing later, not
  synchronously within the same tick -- see `docs/ultracode/PROGRESS.md`
  for why that's the correct evidentiary boundary between "this epoch
  finished" and "the next epoch started"). `wait_for` (not
  `argument(:x, result(:y))` with an unused `x`) is used specifically
  because these are real ordering constraints, not real data dependencies
  -- ERRC eliminate: the original code declared `argument`/`result`
  bindings whose step bodies never read them, misrepresenting an
  ordering-only need as a data dependency.
  """

  use Reactor

  require Ash.Query

  step :fetch_active_runs do
    run(fn _arguments, _context ->
      Xaas.Ultracode.Run
      |> Ash.Query.filter(state == :running)
      |> Ash.read()
    end)
  end

  step :advance_missed_epochs do
    argument(:active_runs, result(:fetch_active_runs))

    run(fn %{active_runs: active_runs}, _context ->
      {:ok, Xaas.Ultracode.MissedEpochs.advance_all(active_runs)}
    end)
  end

  step :run_active_epochs do
    argument(:active_runs, result(:fetch_active_runs))
    wait_for(:advance_missed_epochs)

    run(fn %{active_runs: active_runs}, _context ->
      results =
        active_runs
        |> Ash.load!(:active_epoch)
        |> Enum.map(& &1.active_epoch)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn epoch ->
          case Reactor.run(Xaas.Ultracode.EpochReactor, %{epoch_id: epoch.id}) do
            {:ok, receipt_summary} -> receipt_summary
            {:error, reason} -> %{epoch_id: epoch.id, outcome: :refused, error: reason}
          end
        end)

      {:ok, results}
    end)
  end

  step :advance_next_epochs do
    argument(:active_runs, result(:fetch_active_runs))
    wait_for(:run_active_epochs)

    run(fn %{active_runs: active_runs}, _context ->
      {:ok, Xaas.Ultracode.NextEpoch.advance_all(active_runs)}
    end)
  end
end
