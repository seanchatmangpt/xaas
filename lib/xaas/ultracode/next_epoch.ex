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
  """

  require Ash.Query
  require Logger

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
        %{run_id: run.id, outcome: :active_epoch_in_progress}

      [%{state: :completed} = last_epoch] ->
        advance_from_completed(run, last_epoch)

      [%{state: state}] ->
        # :missed or :failed -- do not silently retry or skip forward.
        # A real disposition for this case is a separate, not-yet-built
        # decision (retry the same cycle? abandon the Run?), so leave
        # it visible rather than guessing.
        %{run_id: run.id, outcome: :blocked_on_stale_epoch, epoch_state: state}
    end
  end

  defp advance_from_completed(run, last_epoch) do
    if run.cycle < run.max_cycles do
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
        |> Ash.create()

      run
      |> Ash.Changeset.for_update(:advance_cycle, %{})
      |> Ash.update!()

      Logger.info(
        "[ultracode] run #{run.id} advanced to epoch cycle=#{next_epoch.cycle} " <>
          "(epoch_id=#{next_epoch.id})"
      )

      %{run_id: run.id, outcome: :advanced, epoch_id: next_epoch.id, cycle: next_epoch.cycle}
    else
      run
      |> Ash.Changeset.for_update(
        :transition_state,
        %{state: :completed, standing: :admitted}
      )
      |> Ash.update!()

      Logger.info(
        "[ultracode] run #{run.id} reached max_cycles=#{run.max_cycles} -> Run :completed"
      )

      %{run_id: run.id, outcome: :run_completed}
    end
  end
end
