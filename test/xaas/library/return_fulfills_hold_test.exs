defmodule Xaas.Library.ReturnFulfillsHoldTest do
  @moduledoc """
  Chicago-style integration test proving the `Checkout.return` ->
  `HoldRequest.fulfill` wiring added via `Xaas.Library.Changes.FulfillNextHold`:
  returning a checkout on a book with an active hold immediately hands the
  copy to the oldest active hold instead of leaving it on the shelf.

  Also proves the P2 rollback fix in `HoldRequest`'s `:fulfill` action: a
  failed book lookup or failed `:borrow_copy` inside `:fulfill`'s
  `after_action` now returns `{:error, _}` and rolls back the hold's own
  `:status`/`:fulfilled_at` change, instead of the pre-fix bare
  `Ash.Changeset.after_action` silently swallowing the failure and leaving
  the hold marked `:fulfilled` with no copy actually handed out.

  Real Ash resources, real sandboxed Postgres -- no mocks.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.{Book, Checkout, HoldRequest}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user! do
    Xaas.Generator.create_user!()
  end

  # This file's own default (available_copies/total_copies both set to the
  # caller-supplied count) differs deliberately from
  # Xaas.Generator.create_book!/1's own default (2/2) -- these tests
  # specifically need a book that starts fully checked out (0 copies) as
  # the precondition for a hold ever being placed/fulfilled.
  defp create_book!(available_copies) do
    Xaas.Generator.create_book!(%{
      available_copies: available_copies,
      total_copies: available_copies
    })
  end

  defp borrow!(book, user) do
    Checkout
    |> Ash.Changeset.for_create(:borrow, %{
      book_id: book.id,
      user_id: user.id,
      school_id: "willow-creek"
    })
    |> Ash.create!(authorize?: false)
  end

  defp place_hold!(book, user) do
    HoldRequest
    |> Ash.Changeset.for_create(:place, %{
      book_id: book.id,
      user_id: user.id,
      school_id: "willow-creek"
    })
    |> Ash.create!(authorize?: false)
  end

  test "returning a checkout fulfills the oldest active hold instead of leaving the copy on the shelf" do
    borrower = create_user!()
    waiting_reader = create_user!()

    # Single copy, entirely checked out -- available_copies goes to 0, which
    # is the real precondition for a hold ever being placed.
    book = create_book!(1)
    checkout = borrow!(book, borrower)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0

    hold = place_hold!(book, waiting_reader)
    assert hold.status == :active

    returned =
      checkout
      |> Ash.Changeset.for_update(:return, %{})
      |> Ash.update!(authorize?: false)

    assert returned.status == :returned

    # The hold must transition to :fulfilled ...
    hold_after = Ash.get!(HoldRequest, hold.id, authorize?: false)
    assert hold_after.status == :fulfilled
    assert %DateTime{} = hold_after.fulfilled_at

    # ... and available_copies must reflect the NET effect of
    # return (+1) immediately followed by the hold's own re-borrow (-1),
    # i.e. it stays at 0 -- it must NOT be left incremented at 1 as it
    # would be if the hold were merely queued rather than actually fulfilled.
    book_after = Ash.get!(Book, book.id, authorize?: false)
    assert book_after.available_copies == 0
  end

  test "a hold with no waiting readers leaves available_copies incremented (no false fulfillment)" do
    user = create_user!()
    book = create_book!(1)
    checkout = borrow!(book, user)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0

    checkout
    |> Ash.Changeset.for_update(:return, %{})
    |> Ash.update!(authorize?: false)

    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1
  end

  test "a failed borrow_copy during hold fulfillment rolls back the hold's status instead of silently succeeding" do
    reader = create_user!()

    # Book has zero available copies at the moment :fulfill runs, so the
    # inner Book.borrow_copy update's `available_copies > 0` validation
    # fails for real (no mock) -- this is the realistic failure this
    # after_action rollback exists for.
    book = create_book!(0)
    hold = place_hold!(book, reader)
    assert hold.status == :active

    result =
      hold
      |> Ash.Changeset.for_update(:fulfill, %{})
      |> Ash.update(authorize?: false)

    assert {:error, _error} = result

    # P2 fix: the hold's :status/:fulfilled_at change must roll back with
    # the failed after_action, not be left committed as :fulfilled with no
    # copy actually handed out.
    hold_after = Ash.get!(HoldRequest, hold.id, authorize?: false)
    assert hold_after.status == :active
    assert is_nil(hold_after.fulfilled_at)
  end

  # A parallel "failed Book lookup" case (hold.book_id pointing at a
  # nonexistent book) was evaluated and dropped: the real Postgres FK on
  # `library_holds.book_id -> library_books.id` (RESTRICT) makes that state
  # unreachable through real Ash actions -- both forcing a nonexistent
  # `book_id` and destroying a `Book` a hold still references raise a real,
  # database-enforced `Ash.Error.Invalid` before `:fulfill` ever runs. The
  # `:borrow_copy` failure case above is the reachable member of the "failed
  # Book lookup or failed borrow_copy" pair this batch's P2 fix covers, and
  # is exercised with a real, unmocked validation failure.
end
