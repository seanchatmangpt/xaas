defmodule Xaas.Ultracode.Validations.RunTransitionAllowed do
  @moduledoc """
  Real `Ash.Resource.Validation` guarding `Run.:transition_state`: refuses
  (typed error, not a silent no-op) any `{current_state, new_state}` pair
  not in a real, explicit allow-list, rather than accepting any of
  `:pending/:running/:completed/:failed/:abandoned` from any current
  state unconditionally.

  Allow-listed edges, and why each is real:

  - `{:pending, :running}` -- the real, exercised test-bootstrap shortcut
    (`test/xaas/ultracode/{missed_epoch_receipt_test,next_epoch_test,
    epoch_reactor_test}.exs`) that constructs a `:running` Run directly,
    skipping `Run.:start`'s `RunIsPending` guard and
    `Changes.CreateFirstEpoch` side effect, to set up scenarios these
    tests need (a Run already `:running` with a hand-constructed Epoch
    fixture). This edge is intentionally allow-listed -- not excluded
    and not renamed to a separate action -- because every one of its 4
    real current call sites is a test fixture setup step, not a
    production path: production code only ever reaches `:running` via
    the real, validated `Run.:start` (see `RunIsPending` +
    `Changes.CreateFirstEpoch`), and closing this edge would require
    reworking those 4 tests' fixture construction with no real gain in
    safety for the actual production path, which never calls
    `:transition_state` to bootstrap `:running` -- it always calls
    `:start`.
  - `{:running, :completed}` -- the real production edge
    `Xaas.Ultracode.NextEpoch.advance_from_completed/2` uses when a Run
    reaches `max_cycles`.
  - `{:running, :failed}`, `{:running, :abandoned}` -- `:running -> :failed`
    is now REALLY exercised: `Xaas.Ultracode.NextEpoch`'s bounded stale
    recovery transitions an exhausted Run (cycle budget spent on a
    `:missed`/`:failed` last epoch) to `:failed` with the stale state's
    standing. `:running -> :abandoned` is the operator-facing
    `Run.:stop` action's edge. Both were provisioned by this validation's
    original pass; neither was a dead provision anymore once the engine
    landed.
  - `{:pending, :abandoned}` -- `Run.:stop` on a never-started Run: an
    operator may withdraw a pending Run without first admitting it.
  - `{:abandoned, :running}` -- the operator-facing `Run.:resume` action's
    edge (`RunResumable` additionally refuses a resume with no active
    epoch and no remaining cycle budget).

  Before this validation existed, `:transition_state` accepted ANY
  `{current, new}` pair unconditionally -- a real, unvalidated backdoor
  around the state-machine discipline `Run.:start` enforces for its own
  edge. This closes that gap with a real, explicit, checkable edge list
  rather than leaving state-machine correctness entirely to caller
  discipline.
  """

  use Ash.Resource.Validation

  @allowed_edges [
    {:pending, :running},
    {:running, :completed},
    {:running, :failed},
    {:running, :abandoned},
    {:pending, :abandoned},
    {:abandoned, :running}
  ]

  @impl true
  def validate(changeset, _opts, _context) do
    current = Ash.Changeset.get_data(changeset, :state)
    new = Ash.Changeset.get_attribute(changeset, :state)

    if {current, new} in @allowed_edges do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidChanges.exception(
         message:
           "run transition #{inspect(current)} -> #{inspect(new)} is not an admitted edge " <>
             "(allowed: #{inspect(@allowed_edges)})"
       )}
    end
  end
end
