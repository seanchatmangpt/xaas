defmodule Xaas.Library.CascadeCourtW984ehTest do
  @moduledoc """
  W984eh unclaimed-family depth court over the return -> hold-fulfillment
  cascade. Census found every branch of
  `Xaas.Library.Changes.FulfillNextHold` exercised EXCEPT one:
  `fulfill_next_hold.ex:48-49`, the `{:error, error} -> {:error, error}`
  propagation from the cascade's inner `HoldRequest` `:fulfill` call. The
  existing courts cover: cascade success (return_fulfills_hold_test,
  checkout_hold_lifecycle_stress_test, the avatars test), direct `:fulfill`
  failure via `borrow_copy` (return_fulfills_hold_test:110-134), and the
  W984ad borrow-cap refusal on *direct* `:fulfill`
  (checkout_hold_lifecycle_stress_test:182-202). No test drives the
  W984ad refusal through the *cascade*: a return whose oldest active hold
  belongs to a capped reader must propagate that refusal out of the
  after_action and roll the entire return transaction back -- the
  borrower's checkout stays `:borrowed`, inventory stays at 0, the hold
  stays `:active`, and no hand-off Checkout row exists.

  Chicago-style: real Ash resources, real sandboxed Postgres, real cap
  state built through real `:borrow` creates, zero mocks.

  Mutation rationale: killing the `{:error, error} -> {:error, error}`
  branch (replacing it with `{:ok, checkout}` -- the exact pre-P2 bug
  shape) makes test 1 fail, because the return would commit with the
  borrower's row `:returned` while the capped reader's hold silently
  stays `:active` with no copy handed out. Test 2 kills the weaker
  mutation of returning `{:error, ...}` without transactional rollback
  (i.e. a partial commit) by asserting full state reversion across all
  three aggregate roots (Checkout, Book, HoldRequest) in one place.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.{Book, Checkout, HoldRequest}

  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!, do: Xaas.Generator.create_user!()

  # available_copies == total_copies == n (same deliberate divergence from
  # Xaas.Generator.create_book!/1's 2/2 default as return_fulfills_hold_test)
  defp create_book!(n) do
    Xaas.Generator.create_book!(%{available_copies: n, total_copies: n})
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

  defp open_checkout_count(user_id) do
    Checkout
    |> Ash.Query.filter(user_id == ^user_id and status in [:borrowed, :overdue])
    |> Ash.count!(authorize?: false)
  end

  @cap Xaas.Library.Changes.EnforceBorrowCap.max_open_checkouts()

  test "a return whose oldest active hold belongs to a capped reader is refused and rolls back whole" do
    borrower = create_user!()
    capped_reader = create_user!()

    # Drive the capped reader to exactly the cap through real :borrow
    # creates on three distinct real books -- persisted state, not a stub.
    for _ <- 1..@cap do
      borrow!(create_book!(2), capped_reader)
    end

    assert open_checkout_count(capped_reader.id) == @cap

    # The cascade book: single copy, fully checked out by the borrower.
    book = create_book!(1)
    checkout = borrow!(book, borrower)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0

    hold = place_hold!(book, capped_reader)
    assert hold.status == :active

    # The cascade's inner :fulfill now fails the W984ad cap guard for
    # real: borrow_copy succeeds (1 available after the return increment),
    # status flips to :fulfilled in-tx, then EnforceBorrowCap.check sees
    # @cap open rows and refuses -- the after_action error must abort the
    # whole transaction.
    result =
      checkout
      |> Ash.Changeset.for_update(:return, %{})
      |> Ash.update(authorize?: false)

    assert {:error, _error} = result

    # 1. The borrower's checkout row rolled back to :borrowed.
    assert %{status: :borrowed} = Ash.get!(Checkout, checkout.id, authorize?: false)

    # 2. Inventory fully reverted: the return's +1 and the fulfill's -1
    #    both undone -- the copy is still out with the borrower.
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0

    # 3. The hold survived untouched: still :active, unfulfilled.
    hold_after = Ash.get!(HoldRequest, hold.id, authorize?: false)
    assert hold_after.status == :active
    assert is_nil(hold_after.fulfilled_at)

    # 4. No hand-off Checkout was minted for the capped reader on this
    #    book (their @cap pre-existing open rows are on other books).
    refute Checkout
           |> Ash.Query.filter(user_id == ^capped_reader.id and book_id == ^book.id)
           |> Ash.exists?(authorize?: false)
  end

  test "a second active hold behind the capped oldest hold is untouched by the refused return" do
    borrower = create_user!()
    capped_reader = create_user!()
    second_reader = create_user!()

    for _ <- 1..@cap do
      borrow!(create_book!(2), capped_reader)
    end

    book = create_book!(1)
    checkout = borrow!(book, borrower)

    oldest = place_hold!(book, capped_reader)
    second = place_hold!(book, second_reader)

    result =
      checkout
      |> Ash.Changeset.for_update(:return, %{})
      |> Ash.update(authorize?: false)

    assert {:error, _error} = result

    # Both holds untouched: the queue position did not shift on failure.
    assert %{status: :active} = Ash.get!(HoldRequest, oldest.id, authorize?: false)
    assert %{status: :active} = Ash.get!(HoldRequest, second.id, authorize?: false)

    # Neither reader holds a hand-off row on this book.
    refute Checkout
           |> Ash.Query.filter(book_id == ^book.id and user_id in ^[capped_reader.id, second_reader.id])
           |> Ash.exists?(authorize?: false)
  end
end
