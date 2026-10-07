defmodule Xaas.A2a.Validations.ForwardOnlyTransition do
  @moduledoc """
  Real `Ash.Resource.Validation` guarding `Xaas.A2a.Task.:update`: refuses
  (typed `Ash.Error.Changes.InvalidChanges`) any `{current_status, new_status}`
  pair not in an explicit allow-list, closing the gap W751 pinned as
  UNSUPPORTED(transition-machine): `:update` accepted any in-set status ->
  any in-set status, including terminal `:completed` -> `:submitted`.

  Edge choice — consumer evidence for `Xaas.A2a.Task` is thin (the only
  status writers are tests; no production writer exists yet), so the
  conservative choice is made and documented:

  - Self-transitions `{s, s}` are allowed: an artifacts-only `:update`
    leaves `:status` unchanged, and that must not be refused.
  - Forward edges follow the A2A task-state semantics the `one_of` set
    already implies (`:submitted -> :working -> :input_required` ->
    `:working` -> `:completed`/`:failed`), with `:completed`/`:failed`
    as absorbing terminal states — NO edge leaves a terminal state.
  - `:cancelled` is not in the resource's `one_of` set (refused upstream by
    the membership constraint), so it appears in no edge here.

  Allowed edges:

      {:submitted, :working}
      {:submitted, :input_required}
      {:submitted, :completed}
      {:submitted, :failed}
      {:working, :input_required}
      {:working, :completed}
      {:working, :failed}
      {:input_required, :working}
      {:input_required, :completed}
      {:input_required, :failed}
      plus every {:s, :s} self-transition.

  Idiom mirror: `Xaas.Ultracode.Validations.RunTransitionAllowed`.
  """

  use Ash.Resource.Validation

  @forward_edges [
    {:submitted, :working},
    {:submitted, :input_required},
    {:submitted, :completed},
    {:submitted, :failed},
    {:working, :input_required},
    {:working, :completed},
    {:working, :failed},
    {:input_required, :working},
    {:input_required, :completed},
    {:input_required, :failed}
  ]

  def forward_edges, do: @forward_edges

  @impl true
  def validate(changeset, _opts, _context) do
    current = Ash.Changeset.get_data(changeset, :status)
    new = Ash.Changeset.get_attribute(changeset, :status)

    if {current, new} in @forward_edges or current == new do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidChanges.exception(
         message:
           "a2a task status transition #{inspect(current)} -> #{inspect(new)} is not an admitted " <>
             "forward edge (allowed: #{inspect(@forward_edges)} plus self-transitions)"
       )}
    end
  end
end
