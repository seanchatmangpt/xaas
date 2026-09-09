defmodule Xaas.Library.Changes.FulfillNextHold do
  @moduledoc """
  Ash change that fulfills the oldest active hold (if any) on the book being
  returned by a checkout, so a returned copy is immediately handed to the
  next reader in the hold queue.

  Runs in the same `after_action` step as `Xaas.Library.Changes.IncrementBookInventory`
  on `Xaas.Library.Checkout`'s `:return` action, inside the same transaction
  boundary, so the return, the inventory increment, and the hold fulfillment
  (which itself re-decrements inventory via `HoldRequest`'s `:fulfill` ->
  `Book.borrow_copy`) commit or roll back together.
  """
  use Ash.Resource.Change
  alias Xaas.Library.HoldRequest

  @impl true
  def change(changeset, _opts, _context) do
    book_id = Ash.Changeset.get_attribute(changeset, :book_id)

    if book_id do
      Ash.Changeset.after_action(changeset, fn _changeset, checkout ->
        # `get?: true` on `:oldest_active_for_book` asserts single-result
        # semantics but does not itself limit the query -- when more than
        # one hold is active on this book (the real, common case a hold
        # queue exists for), Ash.read_one/2 raises
        # Ash.Error.Invalid.MultipleResults instead of returning the
        # oldest one. The action's own `sort: [inserted_at: :asc]` only
        # orders the result set; `Ash.Query.limit(1)` is what actually
        # narrows it to "the oldest," matching this change's documented
        # intent.
        case HoldRequest
             |> Ash.Query.for_read(:oldest_active_for_book, %{book_id: book_id})
             |> Ash.Query.limit(1)
             |> Ash.read_one(authorize?: false) do
          {:ok, %HoldRequest{} = hold} ->
            # Real result match, not a discarded call -- returning
            # `{:error, _}` from an `after_action` hook aborts the action
            # and rolls back the surrounding transaction. Previously this
            # branch always returned `{:ok, checkout}` regardless of
            # whether `:fulfill` (which itself re-decrements Book
            # inventory) actually succeeded, so a real failure here --
            # e.g. a concurrent fulfillment of the same hold -- was
            # invisible to the caller and left the return "succeeded"
            # with no copy actually handed out.
            case hold
                 |> Ash.Changeset.for_update(:fulfill, %{})
                 |> Ash.update(authorize?: false) do
              {:ok, _hold} -> {:ok, checkout}
              {:error, error} -> {:error, error}
            end

          # `{:ok, nil}` -- no active hold on this book -- is the
          # expected, non-error case (an empty queue), distinct from a
          # real query failure below.
          {:ok, nil} ->
            {:ok, checkout}

          {:error, error} ->
            {:error, error}
        end
      end)
    else
      changeset
    end
  end
end
