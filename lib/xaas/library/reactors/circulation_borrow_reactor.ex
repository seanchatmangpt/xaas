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
      # If zero copies available, automatically place in Hold queue
      create :create_hold, HoldRequest, :create do
        inputs %{
          book_id: input(:book_id),
          user_id: input(:user_id),
          school_id: input(:school_id)
        }
      end
    end
  end

  return :circulation_branch
end
