defmodule Xaas.Ultracode.Validations.EpochTransitionAllowed do
  @moduledoc """
  Real `Ash.Resource.Validation` guarding `Epoch.:complete`/`:mark_missed`/
  `:mark_failed`: refuses (typed error, not a silent no-op) unless the
  Epoch's current `state` is one of `opts[:from]`. Same shape as
  `Xaas.Ultracode.Validations.RunIsPending` -- an application-level
  pre-flight check -- generalized to take the admissible source states as
  an option, since each of the three actions this guards has a different
  admissible-from set (`:complete` from `:running` only; `:mark_missed`/
  `:mark_failed` from `:expected` or `:running`).

  Before this validation existed, `:complete`/`:mark_missed`/`:mark_failed`
  applied their `set_attribute` unconditionally from ANY current state --
  correctness was entirely outsourced to callers filtering to admissible
  states upstream (which every current real caller happens to do, hence
  zero test changes were needed when this was added). This closes that gap
  with real defense in depth on the resource itself, matching `Run.:start`'s
  own `RunIsPending` guard.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, opts, _context) do
    allowed = Keyword.fetch!(opts, :from)
    current = Ash.Changeset.get_data(changeset, :state)

    if current in allowed do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidChanges.exception(
         message: "epoch must be in #{inspect(allowed)} for this transition, was #{inspect(current)}"
       )}
    end
  end
end
