defmodule Xaas.Ultracode.Changes.CreateFirstEpoch do
  @moduledoc """
  Closes ULTRACODE-50 blocker (2): nothing previously transitioned a fresh
  `Run` from `:pending` to `:running`, nor constructed its very first
  `Epoch` -- so a Run created via `Xaas.Ultracode.Run.:create` had no real
  admitted path into the tick-driven epoch machinery at all
  (`docs/ultracode/PROGRESS.md`'s prior cycles bridged this by hand in
  test setup, explicitly disclosed as an open gap).

  Wired onto `Run.:start` (see that action): after the Run's own `:state`/
  `:started_at`/`:cycle` attribute changes commit, this creates the Run's
  first `Epoch` (`cycle: <the Run's pre-increment cycle value>`,
  `exact_subject:` the action's required `:exact_subject` argument,
  `state: :expected`) via the real admitted `Epoch.:create` action.

  Uses `changeset.data.cycle` (the Run's cycle value BEFORE this action's
  own `change increment(:cycle)` commits) for the new Epoch's `cycle` --
  the same convention `Xaas.Ultracode.NextEpoch.advance_from_completed/2`
  already uses: a Run's `cycle` attribute holds "the cycle number to
  assign to the epoch being constructed right now", and is bumped
  immediately after so it's ready for whichever admitted path constructs
  the next one.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    original_cycle = changeset.data.cycle
    subject = Ash.Changeset.get_argument(changeset, :exact_subject)

    Ash.Changeset.after_action(changeset, fn _changeset, run ->
      Xaas.Ultracode.Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: original_cycle,
          exact_subject: subject,
          state: :expected,
          expected_at: DateTime.utc_now()
        },
        authorize?: false
      )
      |> Ash.create()
      |> case do
        {:ok, _epoch} -> {:ok, run}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
