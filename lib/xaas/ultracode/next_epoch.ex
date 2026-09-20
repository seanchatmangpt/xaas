defmodule Xaas.Ultracode.NextEpoch do
  @moduledoc """
  Closes blocker (1) from the ULTRACODE-50 milestone falsifier: once a
  `Run`'s active `Epoch` reaches `:completed`, nothing previously
  constructed `Epoch{cycle: N+1}` -- `Xaas.Ultracode.Reactor.
  run_active_epochs/0` only ever acts on an epoch already in `:expected`/
  `:running`, so a `Run` silently stalled forever after its first epoch
  completed even though `AshOban`'s `:tick` kept firing every minute.

  Scope is deliberately narrow: this module only advances a `Run` that
  already has at least one prior `Epoch` (i.e. whose most recent epoch is
  `:completed`). It does NOT create a Run's very first `Epoch` -- that is
  Run-admission's responsibility (the still-open blocker (2): nothing
  transitions a fresh `Run` from `:pending` to `:running` either, so
  "what gives a brand-new Run its first Epoch" is the same open problem,
  intentionally left for a separate cycle rather than folded in here).

  Real `Ash.create!`/`Ash.update!` side effects, no in-memory-only
  bookkeeping -- same evidentiary standard as `Xaas.Ultracode.MissedEpochs`.

  ## Duration-budget dispatch gate

  This module is the epoch DISPATCH site for `:running` Runs, so it is one
  of the law's enforcement points (`Xaas.Ultracode.DurationBudget` is the
  single source of truth): an exhausted Run gets NO new epoch -- ever --
  and, once nothing is in flight anymore, is transitioned to terminal
  `:completed` with a final receipt instead of silently sitting `:running`
  past its boundary. A live in-flight epoch is drained, not dispatched
  over (`:budget_draining` outcome); a terminal-but-stale epoch
  (`:missed`/`:failed`) at an exhausted Run is the drained state that
  completes the run. Runs with `started_at: nil` have no budget in force
  and keep this module's exact prior behavior.
  """

  require Ash.Query
  require Logger

  alias Xaas.Ultracode.DurationBudget

  @doc """
  Scans every `:running` `Run` and, for any with no currently-active
  `Epoch` (none in `:expected`/`:running`), either constructs the next
  `Epoch` (reusing the prior epoch's `exact_subject` -- the subject the
  Run is operating against does not change cycle-to-cycle by default) or,
  if `run.cycle >= run.max_cycles`, transitions the `Run` itself to
  `:completed`. Returns a real per-run outcome list, not a boolean.
  """
  @spec advance_all() :: [map()]
  def advance_all do
    {:ok, active_runs} =
      Xaas.Ultracode.Run
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(state == :running)
      |> Ash.read()

    advance_all(active_runs)
  end

  # ERRC reduce: `Xaas.Ultracode.Reactor`'s tick already fetches every
  # `:running` Run once per tick for its own step; this lets that same
  # list be passed in here instead of this module re-scanning the Run
  # table independently. `advance_all/0` above stays as a real, still-
  # querying standalone entry point for direct/manual invocation.
  @spec advance_all([Xaas.Ultracode.Run.t()]) :: [map()]
  def advance_all(active_runs) when is_list(active_runs) do
    Enum.map(active_runs, &advance_run/1)
  end

  @spec advance_run(Xaas.Ultracode.Run.t()) :: map()
  def advance_run(%Xaas.Ultracode.Run{} = run) do
    # ERRC reduce: previously a separate `Ash.exists?` (has_active?) plus a
    # second, independent `Ash.read` for the most recent epoch -- two round
    # trips computing overlapping information. Collapsed to one query for
    # the most-recent-by-cycle epoch (no state filter); its state alone
    # tells us both whether it's active AND what to do next. This relies on
    # the real, DB-enforced `AtMostOneActiveEpoch` invariant
    # (`Xaas.Ultracode.Validations.AtMostOneActiveEpoch`) plus this
    # module's own construction discipline (a next epoch is only ever
    # created once no active epoch remains, so cycle numbers strictly
    # increase and the highest-cycle epoch is always the Run's current
    # one) -- the same assumption `Xaas.Ultracode.Reactor.active_epoch_id/1`
    # already relies on in this same subsystem.
    {:ok, recent_epochs} =
      Xaas.Ultracode.Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.Query.sort(cycle: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read()

    case recent_epochs do
      [] ->
        # No epoch has ever existed for this Run -- first-epoch
        # construction belongs to Run admission (open blocker (2)),
        # not to this advance-to-next-epoch module.
        %{run_id: run.id, outcome: :no_prior_epoch}

      [%{state: state}] when state in [:expected, :running] ->
        # Duration-budget observability: an active epoch on an exhausted
        # Run is the DRAINING state -- no new dispatch happens here anyway,
        # but the outcome names the boundary instead of silently parking
        # (a run cannot silently exceed its budget). Not exhausted ->
        # exactly the prior outcome.
        now = DurationBudget.now()

        if DurationBudget.exhausted?(run, now) do
          %{run_id: run.id, outcome: :budget_draining, epoch_state: state}
        else
          %{run_id: run.id, outcome: :active_epoch_in_progress}
        end

      [%{state: :completed} = last_epoch] ->
        advance_from_completed(run, last_epoch)

      [%{state: state} = last_epoch] when state in [:missed, :failed] ->
        # Bounded recovery (the engine's disposition for terminal-stale
        # epochs) -- UNLESS the Run's duration budget is exhausted: past
        # the boundary no retry can be scheduled anyway, the stale epoch
        # IS the drained in-flight work, and the run must reach its
        # terminal state + final receipt rather than keep cycling or sit
        # `:running` forever (a run cannot silently exceed its budget in
        # either direction). Budget not in force -> the recovery, exactly.
        now = DurationBudget.now()

        if DurationBudget.exhausted?(run, now) do
          complete_budget_exhausted(run, now, drained_epoch_state: state)
        else
          recover_from_terminal_stale(run, last_epoch, state)
        end
    end
  end

  # XAAS-2601: the pipeline's real side effects carry the real system
  # authority actor so the internal-mutation policies (Run/Epoch) evaluate
  # a genuine admitted actor instead of nil.
  defp advance_from_completed(run, last_epoch) do
    system_actor = Xaas.SystemAuthority.new(:ultracode_reactor)
    now = DurationBudget.now()

    cond do
      # Duration-budget dispatch gate: an exhausted Run gets NO new epoch
      # (this is the dispatch site; the gate precedes max_cycles because
      # "cannot silently exceed budget" outranks cycle headroom). With
      # the last epoch terminal, the run itself completes now.
      DurationBudget.exhausted?(run, now) ->
        complete_budget_exhausted(run, now, last_epoch_state: :completed)

      run.cycle < run.max_cycles ->
        {:ok, next_epoch} = construct_next_epoch(run, last_epoch, system_actor)

        Logger.info(
          "[ultracode] run #{run.id} advanced to epoch cycle=#{next_epoch.cycle} " <>
            "(epoch_id=#{next_epoch.id})"
        )

        %{run_id: run.id, outcome: :advanced, epoch_id: next_epoch.id, cycle: next_epoch.cycle}

      true ->
        run
        |> Ash.Changeset.for_update(
          :transition_state,
          %{state: :completed, standing: :admitted}
        )
        |> Ash.update!(actor: system_actor)

        Logger.info(
          "[ultracode] run #{run.id} reached max_cycles=#{run.max_cycles} -> Run :completed"
        )

        %{run_id: run.id, outcome: :run_completed}
    end
  end

  # Terminal transition + final receipt for a Run whose budget is
  # exhausted and whose in-flight work is fully drained (drained_epoch_
  # state / last_epoch_state record WHAT was in flight when the boundary
  # won). Uses the existing `:transition_state` action; the receipt is
  # `DurationBudget.final_receipt/3` (waves run, epochs
  # terminal-counted, duration actual vs budget). Carries the same
  # system authority actor as every other tick-pipeline mutation
  # (XAAS-2601).
  defp complete_budget_exhausted(run, now, extra) do
    system_actor = Xaas.SystemAuthority.new(:ultracode_reactor)

    completed =
      run
      |> Ash.Changeset.for_update(
        :transition_state,
        %{state: :completed, standing: :admitted}
      )
      |> Ash.update!(actor: system_actor)

    receipt = DurationBudget.final_receipt(completed, now)

    Logger.info(
      "[ultracode] run #{run.id} duration budget exhausted " <>
        "(budget=#{completed.duration_budget_seconds}s, waves_run=#{completed.waves_run}) -> " <>
        "Run :completed, final receipt sealed"
    )

    Map.merge(
      %{run_id: run.id, outcome: :run_completed_budget_exhausted, receipt: receipt},
      Map.new(extra)
    )
  end

  # Bounded recovery after a terminal `:missed`/`:failed` epoch -- the
  # shared epoch-construction + cycle-advance body used by both the
  # completed advance and the stale recovery, so the construction
  # discipline (cycle numbering, subject reuse, expected_at) exists exactly
  # once. Carries the same XAAS-2601 system authority actor.
  defp recover_from_terminal_stale(run, last_epoch, stale_state) do
    system_actor = Xaas.SystemAuthority.new(:ultracode_reactor)

    if run.cycle < run.max_cycles do
      {:ok, next_epoch} = construct_next_epoch(run, last_epoch, system_actor)

      Logger.warning(
        "[ultracode] run #{run.id} recovering from #{stale_state} epoch " <>
          "#{last_epoch.id}: constructed replacement epoch cycle=#{next_epoch.cycle} " <>
          "(epoch_id=#{next_epoch.id})"
      )

      %{
        run_id: run.id,
        outcome: :recovered_from_stale_epoch,
        prior_epoch_state: stale_state,
        epoch_id: next_epoch.id,
        cycle: next_epoch.cycle
      }
    else
      standing = if stale_state == :missed, do: :blocked, else: :refused

      run
      |> Ash.Changeset.for_update(:transition_state, %{state: :failed, standing: standing})
      |> Ash.update!(actor: system_actor)

      Logger.warning(
        "[ultracode] run #{run.id} exhausted max_cycles=#{run.max_cycles} after a " <>
          "#{stale_state} epoch -> Run :failed (standing :#{standing})"
      )

      %{
        run_id: run.id,
        outcome: :run_failed,
        prior_epoch_state: stale_state,
        standing: standing
      }
    end
  end

  defp construct_next_epoch(run, last_epoch, system_actor) do
    {:ok, next_epoch} =
      Xaas.Ultracode.Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          # Denormalized from the parent Run -- kept in sync at every
          # real Epoch-create call site (see Epoch's own moduledoc "Org
          # scoping" section); an org-less Run's next epoch stays
          # org-less too.
          org_id: run.org_id,
          cycle: run.cycle,
          exact_subject: last_epoch.exact_subject,
          state: :expected,
          expected_at: DateTime.utc_now()
        }
      )
      |> Ash.create(actor: system_actor)

    run
    |> Ash.Changeset.for_update(:advance_cycle, %{})
    |> Ash.update!(actor: system_actor)

    {:ok, next_epoch}
  end
end
