defmodule Xaas.Library.CheckoutPolicyDeepeningTest do
  @moduledoc """
  W796 checkout circulation-policy deepening, Chicago-style over real Ash
  actions on the sandboxed Postgres. Probes four undocketed surfaces:

  (a) per-student concurrent-checkout cap -- CLOSED by W902 (W796-G1):
      `:borrow` refuses typed once a student holds 3 open (:borrowed/
      :overdue) checkouts, aggregate across books, read fresh from the
      database before DecrementBookInventory fires. Previously there was
      no cap at all: a student could drain every copy of every book.
  (b) hold interaction -- `Checkout.return` runs
      `Xaas.Library.Changes.FulfillNextHold`: the oldest active hold is
      auto-fulfilled (status :fulfilled, fulfilled_at set, inventory
      re-decremented via HoldRequest :fulfill -> Book.borrow_copy). No
      notification record is created; since W970b (W796-G3), fulfillment
      mints exactly one open hand-off Checkout for the waiting reader.
  (c) return-of-unborrowed / double-return -- CLOSED by W809: `:return`
      now refuses typed (InvalidArgument on :status) unless the checkout
      is OPEN (:borrowed or :overdue). Previously a second :return
      succeeded silently and incremented inventory past total_copies.
  (d) determinism -- hold queue positions are deterministic (1, 2, ...)
      and repeated returns are stable in final row state.

  No mocks. No @moduletag :eu_ai_act.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.{Book, Checkout, HoldRequest}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!, do: Xaas.Generator.create_user!()

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
    |> Ash.create!(actor: user)
  end

  defp return!(checkout, actor) do
    checkout
    |> Ash.Changeset.for_update(:return, %{})
    |> Ash.update!(actor: actor)
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

  defp copies!(book_id), do: Ash.get!(Book, book_id, authorize?: false).available_copies

  defp open_checkouts_for(user_id) do
    Checkout
    |> Ash.Query.for_read(:for_user, %{user_id: user_id})
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&(&1.status == :borrowed))
  end

  # ---------------------------------------------------------------------------
  # (a) per-student concurrent-checkout cap: enforced at 3 (W902, W796-G1)
  # ---------------------------------------------------------------------------

  test "a single student is capped at 3 open checkouts -- the 4th borrow of one book is refused" do
    user = create_user!()
    book = create_book!(5)

    for _ <- 1..3, do: borrow!(book, user)

    assert length(open_checkouts_for(user.id)) == 3
    # Cap reached: the 4th borrow of the same book is refused typed BEFORE
    # DecrementBookInventory -- inventory stays at 2, not 1. (Mutating the
    # guard away re-allows the drain: 4 successes, copies 5 -> 1.)
    assert {:error, %Ash.Error.Invalid{} = error} =
             Checkout
             |> Ash.Changeset.for_create(:borrow, %{
               book_id: book.id,
               user_id: user.id,
               school_id: "willow-creek"
             })
             |> Ash.create(actor: user)

    assert [%{field: :user_id} | _] = error.errors
    assert copies!(book.id) == 2
  end

  test "the cap is aggregate across books, not per-book" do
    user = create_user!()
    books = for _ <- 1..4, do: create_book!(1)

    Enum.take(books, 3) |> Enum.each(&borrow!(&1, user))
    assert length(open_checkouts_for(user.id)) == 3

    # A 4th open checkout -- on a different book -- is still refused.
    assert {:error, %Ash.Error.Invalid{} = error} =
             Checkout
             |> Ash.Changeset.for_create(:borrow, %{
               book_id: Enum.at(books, 3).id,
               user_id: user.id,
               school_id: "willow-creek"
             })
             |> Ash.create(actor: user)

    assert [%{field: :user_id} | _] = error.errors

    # Another student is unaffected by the first student's cap state.
    other = create_user!()
    borrow!(Enum.at(books, 3), other)
    assert length(open_checkouts_for(other.id)) == 1
  end

  test "a returned checkout frees cap capacity for a new borrow" do
    user = create_user!()
    book = create_book!(3)

    for _ <- 1..3, do: borrow!(book, user)
    assert {:error, %Ash.Error.Invalid{}} =
             Checkout
             |> Ash.Changeset.for_create(:borrow, %{
               book_id: book.id,
               user_id: user.id,
               school_id: "willow-creek"
             })
             |> Ash.create(actor: user)

    # Return one: open count drops to 2, the next borrow succeeds again.
    checkout = hd(open_checkouts_for(user.id))
    return!(checkout, user)

    fourth = borrow!(book, user)
    assert fourth.status == :borrowed
  end

  test "one student holding one copy does not block another borrow of the same book" do
    u1 = create_user!()
    u2 = create_user!()
    book = create_book!(2)

    borrow!(book, u1)
    borrow!(book, u2)

    assert length(open_checkouts_for(u1.id)) == 1
    assert length(open_checkouts_for(u2.id)) == 1
    assert copies!(book.id) == 0
  end

  # ---------------------------------------------------------------------------
  # (b) hold-request interaction: return auto-fulfills the oldest active hold
  # ---------------------------------------------------------------------------

  test "return on an exhausted book hands the copy to the oldest hold (re-decrementing inventory)" do
    borrower = create_user!()
    waiting = create_user!()
    book = create_book!(1)

    checkout = borrow!(book, borrower)
    assert copies!(book.id) == 0

    hold = place_hold!(book, waiting)
    assert hold.status == :active
    assert hold.position == 1

    returned = return!(checkout, borrower)

    assert returned.status == :returned
    assert returned.returned_at != nil

    fulfilled = Ash.get!(HoldRequest, hold.id, authorize?: false)
    assert fulfilled.status == :fulfilled
    assert fulfilled.fulfilled_at != nil

    # FulfillNextHold -> HoldRequest :fulfill -> Book.borrow_copy: the copy
    # never rests on the shelf; it is handed straight to the hold reader.
    assert copies!(book.id) == 0

    # W970b (W796-G3 close): fulfillment really mints the physical hand-off
    # Checkout for the waiting reader, in the same transaction as the
    # inventory re-decrement. Exactly one open, correctly-bound row exists.
    assert length(open_checkouts_for(waiting.id)) == 1

    handoff = hd(open_checkouts_for(waiting.id))
    assert handoff.status == :borrowed
    assert handoff.book_id == book.id
    assert handoff.user_id == waiting.id
    assert handoff.returned_at == nil
  end

  test "only the OLDEST active hold is fulfilled; later holds stay active" do
    borrower = create_user!()
    first = create_user!()
    second = create_user!()
    book = create_book!(1)

    checkout = borrow!(book, borrower)
    assert copies!(book.id) == 0

    h1 = place_hold!(book, first)
    # Distinct inserted_at so "oldest" is well-defined.
    Process.sleep(5)
    h2 = place_hold!(book, second)
    assert h1.position == 1
    assert h2.position == 2

    return!(checkout, borrower)

    assert Ash.get!(HoldRequest, h1.id, authorize?: false).status == :fulfilled
    still_active = Ash.get!(HoldRequest, h2.id, authorize?: false)
    assert still_active.status == :active
    assert still_active.fulfilled_at == nil

    # Only one copy changed hands; the second hold waits for the next return.
    assert copies!(book.id) == 0
  end

  test "no notification record is created by fulfillment -- PubSub broadcast only" do
    borrower = create_user!()
    waiting = create_user!()
    book = create_book!(1)

    checkout = borrow!(book, borrower)
    place_hold!(book, waiting)

    returned = return!(checkout, borrower)

    # No notification artifact is written anywhere: fulfillment's only
    # durable side effects are the hold row's status/fulfilled_at, the
    # inventory re-decrement, the W970b hand-off Checkout for the waiting
    # reader, and an ephemeral PubSub broadcast (not asserted here).
    assert returned.status == :returned
    assert returned.returned_at != nil

    # W970b (W796-G3 close): the one durable row fulfillment mints beyond
    # the hold update is the hand-off Checkout -- open, for the waiting
    # reader, bound to the same book.
    assert length(open_checkouts_for(waiting.id)) == 1

    handoff = hd(open_checkouts_for(waiting.id))
    assert handoff.status == :borrowed
    assert handoff.book_id == book.id
    assert handoff.user_id == waiting.id
    assert handoff.returned_at == nil

    hold = place_hold_parent(waiting, book)
    assert hold.status == :fulfilled
    assert hold.fulfilled_at != nil
  end

  # ---------------------------------------------------------------------------
  # (c) return-of-unborrowed / double-return: refused typed (W809 guard)
  # ---------------------------------------------------------------------------

  test "double return is refused typed and inventory is unchanged" do
    user = create_user!()
    book = create_book!(1)

    checkout = borrow!(book, user)
    assert copies!(book.id) == 0

    return!(checkout, user)
    assert copies!(book.id) == 1

    # W809: :return now verifies the checkout is open (:borrowed/:overdue).
    # A second return is refused -- without the guard this call succeeded
    # and bumped available_copies to 2, past total_copies = 1.
    assert {:error, %Ash.Error.Invalid{} = error} =
             checkout
             |> Ash.Changeset.for_update(:return, %{})
             |> Ash.update(actor: user)

    assert [%{field: :status} | _] = error.errors

    # Inventory was NOT inflated by the refused return.
    assert copies!(book.id) == 1
  end

  test "returning a checkout that was never actually borrowed (created :returned) is refused" do
    user = create_user!()
    book = create_book!(1)

    # A row minted via the primary :create with status :returned from the
    # start -- "unborrowed" by construction. W809: :return refuses it;
    # previously the increment still fired, inflating available_copies to 2.
    unborrowed =
      Checkout
      |> Ash.Changeset.for_create(:create, %{
        book_id: book.id,
        user_id: user.id,
        school_id: "willow-creek",
        status: :returned,
        returned_at: DateTime.utc_now()
      })
      |> Ash.create!(actor: user)

    assert copies!(book.id) == 1

    assert {:error, %Ash.Error.Invalid{}} =
             unborrowed
             |> Ash.Changeset.for_update(:return, %{})
             |> Ash.update(actor: user)

    assert copies!(book.id) == 1
  end

  test "double return with a hold queued: second return refused, inventory unchanged" do
    user = create_user!()
    waiting = create_user!()
    book = create_book!(1)

    checkout = borrow!(book, user)
    place_hold!(book, waiting)

    return!(checkout, user)
    # First return: hold fulfilled, inventory back to 0 (re-borrowed by hold).
    assert copies!(book.id) == 0

    # W809: the second return is refused before any change fires --
    # previously IncrementBookInventory still ran, inflating inventory 0 -> 1.
    assert {:error, %Ash.Error.Invalid{}} =
             checkout
             |> Ash.Changeset.for_update(:return, %{})
             |> Ash.update(actor: user)

    assert copies!(book.id) == 0
  end

  test "an OVERDUE checkout is still open and returns successfully" do
    user = create_user!()
    book = create_book!(1)

    checkout = borrow!(book, user)
    # Flip to :overdue directly (real open state per the status one_of).
    overdue =
      checkout
      |> Ash.Changeset.for_update(:update, %{status: :overdue})
      |> Ash.update!(actor: user)

    assert overdue.status == :overdue

    returned = return!(overdue, user)
    assert returned.status == :returned
    assert returned.returned_at != nil
    assert copies!(book.id) == 1
  end

  # ---------------------------------------------------------------------------
  # (d) determinism
  # ---------------------------------------------------------------------------

  test "hold queue positions are deterministic: 1, 2, ... by placement order" do
    user = create_user!()
    other = create_user!()
    book = create_book!(1)

    borrow!(book, user)
    place_hold!(book, user)
    Process.sleep(5)
    h2 = place_hold!(book, other)

    holds =
      HoldRequest
      |> Ash.Query.for_read(:for_book, %{book_id: book.id})
      |> Ash.read!(authorize?: false)
      |> Enum.sort(&(&1.inserted_at <= &2.inserted_at))

    assert Enum.map(holds, & &1.position) == [1, 2]
    assert h2.position == 2
  end

  test "repeated returns are deterministic in final row state" do
    u1 = create_user!()
    u2 = create_user!()
    book = create_book!(2)

    c1 = borrow!(book, u1)
    c2 = borrow!(book, u2)

    r1 = return!(c1, u1)
    r2 = return!(c2, u2)

    # Identical inputs -> identical observable contract: same terminal
    # status, non-nil returned_at, inventory restored to the starting count.
    assert r1.status == r2.status
    assert r1.returned_at != nil and r2.returned_at != nil
    assert copies!(book.id) == 2
  end

  # -- helpers ---------------------------------------------------------------

  defp place_hold_parent(waiting, book) do
    HoldRequest
    |> Ash.Query.for_read(:for_book, %{book_id: book.id})
    |> Ash.read!(authorize?: false)
    |> Enum.find(&(&1.user_id == waiting.id))
  end
end
