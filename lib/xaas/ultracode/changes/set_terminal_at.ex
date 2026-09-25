defmodule Xaas.Ultracode.Changes.SetTerminalAt do
  @moduledoc """
  Persists the terminal-transition moment: when the changeset's
  destination `:state` is a TERMINAL state, sets `terminal_at` to the
  transition's real wall-clock instant.

  Conditional on purpose: `Run.:transition_state` also carries non-terminal
  edges (`{:pending, :running}`, `{:abandoned, :running}` -- see
  `RunTransitionAllowed`), and only the closing transitions
  (`:completed`/`:failed`/`:abandoned`) are the facts `terminal_at` exists
  to record. Reading the destination state from the changeset (not the
  loaded struct) makes this correct for both call shapes: `:transition_state`
  accepts `:state` as an argument, and `:stop` sets it via an earlier
  `set_attribute` change (DSL changes run in declaration order).

  This column is what the OCEL egress uses as the `run_completed`/
  `run_failed`/`run_abandoned` event time -- replacing the former
  `updated_at` approximation (the last write to the row happened to be the
  transition). A Run without a persisted `terminal_at` emits no terminal
  event rather than a fabricated time. A later terminal transition
  overwrites the column (latest closing moment); a `:resume` leaves it
  standing -- the abandoned moment did happen, and the resumed (non-terminal)
  Run emits no terminal event at all.
  """

  use Ash.Resource.Change

  @terminal_states [:completed, :failed, :abandoned]

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :state) do
      state when state in @terminal_states ->
        Ash.Changeset.force_change_attribute(changeset, :terminal_at, DateTime.utc_now())

      _non_terminal ->
        changeset
    end
  end
end
