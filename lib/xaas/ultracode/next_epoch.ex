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
      |> Ash.Query.filter(state == :running)
      |> Ash.read(authorize?: false)

    Enum.map(active_runs, &advance_run/1)
  end

  @spec advance_run(Xaas.Ultracode.Run.t()) :: map()
  def advance_run(%Xaas.Ultracode.Run{} = run) do
    has_active? =
      Xaas.Ultracode.Epoch
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.Query.filter(state in [:expected, :running])
      |> Ash.exists?(authorize?: false)

    if has_active? do
      %{run_id: run.id, outcome: :active_epoch_in_progress}
    else
      {:ok, prior_epochs} =
        Xaas.Ultracode.Epoch
        |> Ash.Query.filter(run_id == ^run.id)
        |> Ash.Query.sort(cycle: :desc)
        |> Ash.Query.limit(1)
        |> Ash.read(authorize?: false)

      case prior_epochs do
        [] ->
          # No epoch has ever existed for this Run -- first-epoch
          # construction belongs to Run admission (open blocker (2)),
          # not to this advance-to-next-epoch module.
          %{run_id: run.id, outcome: :no_prior_epoch}

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
  end

  defp advance_from_completed(run, last_epoch) do
    if run.cycle < run.max_cycles do
      {:ok, next_epoch} =
        Xaas.Ultracode.Epoch
        |> Ash.Changeset.for_create(
          :create,
          %{
            run_id: run.id,
            cycle: run.cycle,
            exact_subject: last_epoch.exact_subject,
            state: :expected,
            expected_at: DateTime.utc_now()
          },
          authorize?: false
        )
        |> Ash.create()

      run
      |> Ash.Changeset.for_update(:advance_cycle, %{}, authorize?: false)
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
        %{state: :completed, standing: :admitted},
        authorize?: false
      )
      |> Ash.update!()

      Logger.info(
        "[ultracode] run #{run.id} reached max_cycles=#{run.max_cycles} -> Run :completed"
      )

      %{run_id: run.id, outcome: :run_completed}
    end
  end
end
