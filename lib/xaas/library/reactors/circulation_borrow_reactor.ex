defmodule Xaas.Library.Reactors.CirculationBorrowReactor do
  @moduledoc """
  Comprehensive Ash.Reactor saga orchestrating book checkout with inventory verification,
  conditional branching (immediate borrow vs. hold queue via switch), transaction boundaries,
  and compensations.
  """
  use Ash.Reactor

  alias Xaas.Library.{Book, Checkout, HoldRequest}

  ash do
    default_domain Xaas.Library
  end

  input :book_id
  input :user_id
  input :school_id

  # 1. Fetch the book to inspect shelf inventory
  read_one :get_book, Book, :read do
    inputs %{id: input(:book_id)}
    fail_on_not_found? true
  end

  # 2. Branch using Switch step based on availability
  switch :circulation_branch do
    on result(:get_book)

    matches? &(&1.available_copies > 0) do
      # Transaction-wrapped Checkout creation & inventory decrement
      transaction :borrow_transaction, [Checkout, Book] do
        # No redundant guard/where re-validating available_copies here: the
        # read-then-write race is already closed at the resource layer.
        # Checkout.borrow's Xaas.Library.Changes.DecrementBookInventory
        # change calls Book's :borrow_copy update action in the same DB
        # transaction (this transaction block), and :borrow_copy itself
        # carries `validate compare(:available_copies, greater_than: 0)`
        # combined with `atomic_update` (lib/xaas/library/book.ex) -- an
        # Ash atomic changeset, which compiles to a single SQL statement
        # whose WHERE/CHECK re-reads the live row and fails the validation
        # (rolling back this transaction) if a concurrent borrow already
        # drained the last copy between get_book's read and here. Adding a
        # second `where` against the stale `result(:get_book)` value would
        # not close any gap the atomic update doesn't already close -- this
        # is "correctly not using" territory per Book.borrow_copy's existing
        # concurrency guard.
        create :create_checkout, Checkout, :borrow do
          inputs %{
            book_id: input(:book_id),
            user_id: input(:user_id),
            school_id: input(:school_id)
          }
        end

        return :create_checkout
      end
    end

    default do
      # If zero copies available, automatically place in Hold queue.
      # This create is NOT inside a `transaction` block, so it has no
      # automatic DB-transaction rollback if this reactor is later composed
      # into a larger pipeline that fails after the hold is created. Close
      # that no-rollback-across-composition gap with Ash.Reactor's native
      # undo mechanism: `undo_action :cancel` calls HoldRequest's real
      # :cancel update action (lib/xaas/library/hold_request.ex), which
      # actually flips the hold to a cancelled/inactive status rather than
      # a no-op. `undo :outside_transaction` means the undo is skipped when
      # this step happens to run inside a transaction (same-transaction
      # rollback already covers that case) and is invoked otherwise.
      create :create_hold, HoldRequest, :create do
        inputs %{
          book_id: input(:book_id),
          user_id: input(:user_id),
          school_id: input(:school_id)
        }

        undo :outside_transaction
        undo_action :cancel
      end
    end
  end

  return :circulation_branch
end
