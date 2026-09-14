defmodule Xaas.Ultracode.MissedEpochs do
  @moduledoc """
  Real missed-epoch state transition.

  `ExpectedEpoch => not CompletedEpoch => (past run.epoch_timeout_seconds)`
  is enforced here as a real `Epoch.state` transition to `:missed`, not a
  silent forward-advance of `Run.last_expected_epoch_at`. An `Epoch` row
  already in `:expected` or `:running` whose `expected_at` is older than
  its `Run`'s `epoch_timeout_seconds` is transitioned to `:missed` via the
  real `Xaas.Ultracode.Epoch.:mark_missed` update action -- this produces
  a visible, queryable `Epoch` row in `:missed` state. `Run.
  last_expected_epoch_at` is never written by this module: it is left
  exactly as it was, so a caller reading it alongside a `:missed` epoch
  sees real drift (expectation set, not met) instead of a
  quietly-rolled-forward timestamp that would hide the miss.
  """

  require Ash.Query
  require Logger

  @doc """
  Scans every `:running` `Run` and transitions any of its stale
  `:expected`/`:running` `Epoch`s to `:missed`. Returns a real per-run
  summary (not a boolean) so the calling Reactor step has evidence to
  return, not just a side effect.
  """
  @spec advance_all() :: [%{run_id: Ash.UUID.t(), missed: [Ash.UUID.t()]}]
  def advance_all do
    {:ok, active_runs} =
      Xaas.Ultracode.Run
      |> Ash.Query.filter(state == :running)
      |> Ash.read(authorize?: false)

    Enum.map(active_runs, &advance_run/1)
  end

  @doc """
  Transitions one `Run`'s stale epochs to `:missed`. Real per-epoch
  `Ash.update!/1` calls against the real `:mark_missed` action -- no
  in-memory-only bookkeeping.
  """
  @spec advance_run(Xaas.Ultracode.Run.t()) :: %{run_id: Ash.UUID.t(), missed: [Ash.UUID.t()]}
  def advance_run(%Xaas.Ultracode.Run{} = run) do
    now = DateTime.utc_now()
    deadline = DateTime.add(now, -run.epoch_timeout_seconds, :second)

    {:ok, stale_epochs} =
      Xaas.Ultracode.Epoch
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.Query.filter(state in [:expected, :running])
      |> Ash.Query.filter(not is_nil(expected_at) and expected_at < ^deadline)
      |> Ash.read(authorize?: false)

    missed_ids =
      Enum.map(stale_epochs, fn epoch ->
        epoch
        |> Ash.Changeset.for_update(:mark_missed, %{}, authorize?: false)
        |> Ash.update!()

        Logger.warning(
          "[ultracode] epoch #{epoch.id} (run #{run.id}, cycle #{epoch.cycle}) " <>
            "expected_at=#{epoch.expected_at} exceeded epoch_timeout_seconds=" <>
            "#{run.epoch_timeout_seconds} -> marked :missed"
        )

        epoch.id
      end)

    %{run_id: run.id, missed: missed_ids}
  end
end
