defmodule Xaas.Library.Changes.EnforceBorrowCap do
  @moduledoc """
  W984ad (closing W982j's pinned finding): shared per-student borrow-cap
  enforcement, extractable onto BOTH Checkout mint paths.

  W902 batch 3 put the cap (3 open `:borrowed`/`:overdue` checkouts per
  student) inline on `Xaas.Library.Checkout`'s `create :borrow` only.
  W982j proved the hold-fulfillment path structurally bypasses it:
  `HoldRequest`'s `:fulfill` mints its W970b hand-off Checkout via the
  primary `create :create`, which carries no cap guard, so a capped
  patron received a 4th open checkout unrefused.

  This module is the shared form of that guard: a `check/2` helper that
  counts open checkouts fresh from the database (W809/W902
  persisted-state discipline -- never `changeset.data`) and refuses typed
  with the same `InvalidArgument` shape `:borrow` uses. The fulfillment
  path calls `check/2` before minting the hand-off Checkout, so a capped
  patron's `:fulfill` fails before any Checkout row exists, and the
  `after_action` error rolls back the hold status/inventory decrement
  atomically (the hold stays `:active`).

  The `:borrow` inline guard in `Checkout` intentionally remains the
  authoritative copy for this lane (file-ownership boundary); migrating
  it onto this module is a coordinator decision.
  """

  use Ash.Resource.Change

  @max_open_checkouts_per_student 3

  def max_open_checkouts, do: @max_open_checkouts_per_student

  @impl true
  def change(changeset, _opts, _context), do: check(changeset)

  @doc """
  Refuses `changeset` typed if `user_id` already holds `@cap` or more open
  checkouts. Returns `changeset` unchanged (with the error attached) so it
  composes in `before_action` position; on the fulfillment path the error
  is raised/returned from inside `after_action` instead, rolling the whole
  fulfillment transaction back.
  """
  def check(changeset, user_id \\ nil) do
    user_id = user_id || Ash.Changeset.get_argument_or_attribute(changeset, :user_id)

    open_count =
      Xaas.Library.Checkout
      |> Ash.Query.filter(user_id == ^user_id and status in [:borrowed, :overdue])
      |> Ash.count!(authorize?: false)

    if open_count >= @max_open_checkouts_per_student do
      Ash.Changeset.add_error(
        changeset,
        Ash.Error.Changes.InvalidArgument.exception(
          field: :user_id,
          message:
            "per-student borrow cap exceeded: #{open_count} open checkouts " <>
              "(limit #{@max_open_checkouts_per_student}); return one before borrowing again"
        )
      )
    else
      changeset
    end
  end
end
