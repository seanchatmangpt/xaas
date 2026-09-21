defmodule Xaas.Ultracode.Changes.CreateFirstEpoch do
  @moduledoc """
  Constructs the first Epoch exclusively from the admitted Run.:start action.

  The action owns the lifecycle transition. Callers may optionally supply a
  pre-provisioned exact-SHA worktree; this change merely carries that bounded
  execution destination into the first Epoch. It does not provision paths,
  select work, or grant authority.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    original_cycle = changeset.data.cycle
    subject = Ash.Changeset.get_argument(changeset, :exact_subject)
    worktree = Ash.Changeset.get_argument(changeset, :worktree)

    Ash.Changeset.after_action(changeset, fn _changeset, run ->
      Xaas.Ultracode.Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          org_id: run.org_id,
          cycle: original_cycle,
          exact_subject: subject,
          state: :expected,
          expected_at: DateTime.utc_now(),
          worktree: worktree
        }
      )
      |> Ash.create(actor: Xaas.SystemAuthority.new(:ultracode_reactor))
      |> case do
        {:ok, _epoch} -> {:ok, run}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
