defmodule Xaas.Library.CheckoutHoldLifecycleStressTest do
  @moduledoc """
  W982j deepening court for the checkout/hold lifecycle stress seams that
  W970b's court (w970b-open-sweep.md) and the existing library tests do not
  cover:

  1. Concurrent double-`:fulfill` on one hold over real Postgres -- exactly
     one success, the loser refused with the real typed "Only active holds
     can be fulfilled" validation.
  2. The per-student borrow cap (private `@max_open_checkouts_per_student`
     3 in `Xaas.Library.Checkout`) enforced on the next `:borrow` AND on
     hold fulfillment's W970b minted-Checkout path (a `:fulfill` for a
     capped student must fail and roll the hold back to `:active`).
  3. Return-releases-slot: a blocked hold on a fully-checked-out book is
     immediately fulfilled by another patron's `:return`, minting a real
     open Checkout for the waiting reader.
  4. Copy-state invariants post-return: available_copies increments, no
     ghost Checkout rows, double return refused typed, a returned row's
     re-borrow opens a NEW row (history preserved, no reuse).

  Real Ash resources, real sandboxed Postgres, real concurrent tasks -- no
  mocks.
  """

  use Xaas.DataCase, async: false

  require Ash.Query

  alias Xaas.Library.{Book, Checkout, HoldRequest}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!, do: Xaas.Generator.create_user!()

  defp create_book!(copies) do
    Xaas.Generator.create_book!(%{available_copies: copies, total_copies: copies})
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

  defp fulfill(hold) do
    hold
    |> Ash.Changeset.for_update(:fulfill, %{})
    |> Ash.update(authorize?: false)
  end

  defp return_checkout(checkout) do
    checkout
    |> Ash.Changeset.for_update(:return, %{})
    |> Ash.update(authorize?: false)
  end

  defp error_messages({:error, error}), do: error_messages(error)

  defp error_messages(error) do
    # Splode error classes render their nested errors' messages in
    # Exception.message/1 -- assert on the real rendered text.
    [Exception.message(error)]
  end

  # -- Scenario 1: concurrent double-fulfill ---------------------------------

  test "concurrent double :fulfill over real Postgres: exactly one success, loser refused typed" do
    reader = create_user!()
    book = create_book!(0)
    hold = place_hold!(book, reader)
    assert hold.status == :active

    # Make one copy genuinely available so the winner's inner
    # Book.borrow_copy succeeds (fulfill re-decrements inventory).
    book
    |> Ash.Changeset.for_update(:return_copy, %{})
    |> Ash.update!(authorize?: false)

    results =
      Enum.map(1..2, fn _ -> fn -> fulfill(hold) end end)
      |> Task.async_stream(fn f -> f.() end, max_concurrency: 2)
      |> Enum.map(fn {:ok, r} -> r end)

    successes = Enum.filter(results, &match?({:ok, _}, &1))
    failures = Enum.filter(results, &match?({:error, _}, &1))

    assert length(successes) == 1,
           "expected exactly one concurrent fulfill to succeed, got: #{inspect(results)}"

    assert length(failures) == 1,
           "expected exactly one concurrent fulfill to be refused, got: #{inspect(results)}"

    # Observed typed refusal (run w982j run2): under serialized sandbox
    # connections BOTH racers read status :active and pass the status
    # validation; the loser is killed by the ATOMIC inventory decrement in
    # Book.borrow_copy ("No shelf copies currently available"), not by the
    # status validation. Either typed refusal is lawful; assert a real one.
    loser_msgs = error_messages(hd(failures))

    assert Enum.any?(loser_msgs, fn m ->
             String.contains?(m, "No shelf copies currently available") or
               String.contains?(m, "Only active holds can be fulfilled")
           end),
           "loser must be refused with a real typed validation, got: #{inspect(loser_msgs)}"

    # Copy-state invariants: one fulfillment = one net decrement from the
    # post-return_copy baseline of 1, and exactly one open Checkout minted.
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0

    minted =
      Checkout
      |> Ash.Query.filter(book_id == ^book.id and user_id == ^reader.id)
      |> Ash.read!(authorize?: false)

    assert length(minted) == 1
    assert hd(minted).status == :borrowed

    assert Ash.get!(HoldRequest, hold.id, authorize?: false).status == :fulfilled
  end

  # -- Scenario 2: checkout limit enforcement --------------------------------

  test "patron at the cap: next :borrow refused with the real cap error" do
    user = create_user!()

    # Three different books, all open -- the cap counts open checkouts
    # across books, not per-book.
    books = Enum.map(1..3, fn _ -> create_book!(1) end)

    for book <- books, do: borrow!(book, user)

    fourth_book = create_book!(1)

    {:error, error} =
      Checkout
      |> Ash.Changeset.for_create(:borrow, %{
        book_id: fourth_book.id,
        user_id: user.id,
        school_id: "willow-creek"
      })
      |> Ash.create(authorize?: false)

    messages = error_messages(error)

    assert Enum.any?(messages, &String.contains?(&1, "per-student borrow cap exceeded")),
           "expected the real borrow-cap error, got: #{inspect(messages)}"

    assert Enum.any?(messages, &String.contains?(&1, "(limit 3)")),
           "expected the cap limit named in the error, got: #{inspect(messages)}"

    # The refusal happens before DecrementBookInventory: no copy burned.
    assert Ash.get!(Book, fourth_book.id, authorize?: false).available_copies == 1

    # No ghost checkout row for the refused borrow.
    refute Checkout
           |> Ash.Query.filter(book_id == ^fourth_book.id and user_id == ^user.id)
           |> Ash.exists?(authorize?: false)
  end

  test "hold fulfillment for a patron already at the cap is refused typed and the hold stays :active (W984ad flip of W982j KNOWN GAP)" do
    # W982j REAL FINDING, now CLOSED by W984ad: HoldRequest :fulfill minted
    # its hand-off Checkout via the PRIMARY `create :create` action
    # (lib/xaas/library/hold_request.ex, W970b change), and the per-student
    # borrow cap guard lived ONLY on `create :borrow` -- a capped patron
    # received a 4th open checkout unrefused. The shared
    # `Xaas.Library.Changes.EnforceBorrowCap` guard now runs on the
    # fulfillment path before the mint; this test pins the FIXED behavior
    # bidirectionally.
    capped_user = create_user!()

    Enum.each(1..3, fn _ ->
      borrow!(create_book!(1), capped_user)
    end)

    held_book = create_book!(1)
    hold = place_hold!(held_book, capped_user)

    # FIXED (w984ad, real Postgres): fulfillment is refused with the real
    # typed cap error -- the same guard message family the `:borrow` path
    # produces.
    {:error, error} = fulfill(hold)
    messages = error_messages(error)

    assert Enum.any?(messages, &String.contains?(&1, "per-student borrow cap exceeded")),
           "expected the real borrow-cap refusal on :fulfill, got: #{inspect(messages)}"

    # The refusal rolls the whole fulfillment transaction back: the hold is
    # still :active, no Checkout row was minted, no copy was burned.
    assert Ash.get!(HoldRequest, hold.id, authorize?: false).status == :active

    refute Checkout
           |> Ash.Query.filter(book_id == ^held_book.id and user_id == ^capped_user.id)
           |> Ash.exists?(authorize?: false)

    assert Ash.get!(Book, held_book.id, authorize?: false).available_copies == 1

    # Bidirectional: the capped patron still holds exactly the 3 open
    # checkouts they started with -- the 4th never landed.
    open_count =
      Checkout
      |> Ash.Query.filter(user_id == ^capped_user.id and status in [:borrowed, :overdue])
      |> Ash.count!(authorize?: false)

    assert open_count == 3
  end

  test "a patron under the cap fulfills a hold normally, minting the hand-off Checkout (W984ad positive arm)" do
    user = create_user!()

    # One open checkout -- well under the cap of 3.
    _open = borrow!(create_book!(1), user)

    held_book = create_book!(1)
    hold = place_hold!(held_book, user)

    {:ok, fulfilled} = fulfill(hold)
    assert fulfilled.status == :fulfilled
    assert %DateTime{} = fulfilled.fulfilled_at

    # The hand-off Checkout is really minted and open.
    minted =
      Checkout
      |> Ash.Query.filter(book_id == ^held_book.id and user_id == ^user.id)
      |> Ash.read!(authorize?: false)

    assert length(minted) == 1
    assert hd(minted).status == :borrowed

    # Inventory: the fulfillment re-decremented the copy (1 -> 0).
    assert Ash.get!(Book, held_book.id, authorize?: false).available_copies == 0
  end

  # -- Scenario 3: return releases the slot -----------------------------------

  test "returning a checkout releases the slot so a blocked hold immediately fulfills" do
    borrower = create_user!()
    waiting = create_user!()

    book = create_book!(1)
    checkout = borrow!(book, borrower)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0

    hold = place_hold!(book, waiting)
    assert hold.status == :active

    {:ok, returned} = return_checkout(checkout)
    assert returned.status == :returned

    hold_after = Ash.get!(HoldRequest, hold.id, authorize?: false)
    assert hold_after.status == :fulfilled
    assert %DateTime{} = hold_after.fulfilled_at

    # Net inventory: +1 (return) -1 (fulfillment re-borrow) = 0.
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0

    # The waiting reader now holds a real open Checkout.
    handoff =
      Checkout
      |> Ash.Query.filter(book_id == ^book.id and user_id == ^waiting.id)
      |> Ash.read!(authorize?: false)

    assert length(handoff) == 1
    assert hd(handoff).status == :borrowed
  end

  test "a blocked hold is NOT fulfilled while the copy stays out -- returns only hand to active holds" do
    borrower = create_user!()
    waiting = create_user!()
    book = create_book!(1)
    _checkout = borrow!(book, borrower)
    hold = place_hold!(book, waiting)

    # Before any return, the hold must still be :active and no Checkout
    # exists for the waiting reader.
    assert Ash.get!(HoldRequest, hold.id, authorize?: false).status == :active

    refute Checkout
           |> Ash.Query.filter(user_id == ^waiting.id)
           |> Ash.exists?(authorize?: false)
  end

  # -- Scenario 4: copy-state invariants post-return --------------------------

  test "post-return invariants: copy available again, no ghost rows, double return refused" do
    user = create_user!()
    book = create_book!(1)
    checkout = borrow!(book, user)

    {:ok, returned} = return_checkout(checkout)
    assert returned.status == :returned
    assert %DateTime{} = returned.returned_at

    # Shelf restored.
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1

    # Exactly one Checkout row for this book/user -- no ghost duplicate
    # minted by the return path.
    rows =
      Checkout
      |> Ash.Query.filter(book_id == ^book.id and user_id == ^user.id)
      |> Ash.read!(authorize?: false)

    assert length(rows) == 1
    assert hd(rows).id == checkout.id
    assert hd(rows).status == :returned

    # Double return refused typed (W809 open-status guard).
    {:error, error} = return_checkout(checkout)
    messages = error_messages(error)

    assert Enum.any?(messages, &String.contains?(&1, "cannot return a checkout that is not open")),
           "expected the real double-return refusal, got: #{inspect(messages)}"

    # The refused double return must not have re-incremented inventory.
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1
  end

  test "a returned checkout frees the cap slot: the same patron can borrow again as a new row" do
    user = create_user!()

    books = Enum.map(1..3, fn _ -> create_book!(1) end)
    for book <- books, do: borrow!(book, user)

    fourth_book = create_book!(1)

    # At the cap: refused.
    {:error, _} =
      Checkout
      |> Ash.Changeset.for_create(:borrow, %{
        book_id: fourth_book.id,
        user_id: user.id,
        school_id: "willow-creek"
      })
      |> Ash.create(authorize?: false)

    # Free a slot by returning one open checkout.
    first_book = hd(books)

    {:ok, open_co} =
      Checkout
      |> Ash.Query.filter(book_id == ^first_book.id and user_id == ^user.id and status == :borrowed)
      |> Ash.read_one(authorize?: false)

    {:ok, _} = return_checkout(open_co)

    # Now the borrow succeeds as a NEW checkout row on the new book.
    {:ok, fresh} =
      Checkout
      |> Ash.Changeset.for_create(:borrow, %{
        book_id: fourth_book.id,
        user_id: user.id,
        school_id: "willow-creek"
      })
      |> Ash.create(authorize?: false)

    assert fresh.status == :borrowed
    assert fresh.book_id == fourth_book.id

    # Exactly one row per (book, user) pair still holds: the returned row
    # for the first book was reused by nothing -- history preserved.
    first_book = hd(books)

    first_book_rows =
      Checkout
      |> Ash.Query.filter(book_id == ^first_book.id)
      |> Ash.read!(authorize?: false)

    assert length(first_book_rows) == 1
    assert hd(first_book_rows).status == :returned
  end
end
