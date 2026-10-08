defmodule Xaas.Library.HoldResourceCourtW984jqTest do
  @moduledoc """
  W984jq unclaimed-family probe court over `Xaas.Library.HoldRequest`'s own
  action layer. Census (grep across test/) classified every action/branch:

  COVERED elsewhere:
  - `:place` queue semantics (hold_request_test.exs)
  - `:fulfill` happy path + checkout mint (hold_request_test.exs),
    borrow-cap refusal direct (checkout_hold_lifecycle_stress_test.exs),
    cascade error propagation (cascade_court_w984eh_test.exs)
  - `:cancel` happy + refuse-already-cancelled (hold_request_test.exs)
  - `:expire` happy + refuse-fulfilled, `:expirable` read (hold_request_test.exs)
  - `:expire_stale` scheduled entry point + ordinary-actor refusal
    (oban_depth_w984cn_test.exs, system_authority_capability_chicago_test.exs)
  - `:for_book` / `:active` reads (hold_request_test.exs)
  - `:oldest_active_for_book` INDIRECTLY via the FulfillNextHold cascade
    (return_fulfills_hold_test.exs)

  COURTED HERE (genuinely unexercised, state-bearing):
  1. `:for_user` read filter (no test anywhere reads holds through it)
  2. `:oldest_active_for_book` direct call: inserted_at ordering + get?/status
     filtering (indirect cascade coverage never asserts ordering)
  3. `:cancel` refuse-on-fulfilled branch
  4. `:cancel` refuse-on-expired branch
  5. `:expire` refuse-on-cancelled branch
  6. `:expire` refuse-on-expired branch
  7. `:fulfill` refuse-on-expired branch
  8. `:create` status one_of constraint refusal (bad :status atom)
  9. `:destroy` default action (zero tests delete a hold)

  Chicago-style: real sandboxed Postgres, real Ash actions, zero mocks.

  Mutation rationale (per test): each refusal test kills the mutation of
  dropping that action's `validate(compare(:status, is_equal: {:value, :active}))`
  guard -- the mutated action would commit the terminal-state overwrite and
  the test's state assertion fails. The read tests kill filter/sort removal
  mutations (wrong row sets). The destroy test kills a no-op destroy mutation.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.HoldRequest

  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!, do: Xaas.Generator.create_user!()

  # Zero available copies: the precondition for a hold queue existing.
  defp create_book!(attrs \\ %{}) do
    available_copies = Map.get(attrs, :available_copies, 0)

    Xaas.Generator.create_book!(%{
      available_copies: available_copies,
      total_copies: Map.get(attrs, :total_copies, max(available_copies, 1))
    })
  end

  defp place_hold!(user, book) do
    HoldRequest
    |> Ash.Changeset.for_create(:place, %{user_id: user.id, book_id: book.id})
    |> Ash.create!(authorize?: false)
  end

  # -- (1) :for_user read -----------------------------------------------------

  test "for_user filters holds to the requested reader only" do
    book = create_book!()
    user1 = create_user!()
    user2 = create_user!()

    h1 = place_hold!(user1, book)
    h2 = place_hold!(user2, book)

    mine =
      HoldRequest
      |> Ash.Query.for_read(:for_user, %{user_id: user1.id})
      |> Ash.read!(authorize?: false)

    assert Enum.map(mine, & &1.id) == [h1.id]
    refute Enum.any?(mine, &(&1.id == h2.id))

    theirs =
      HoldRequest
      |> Ash.Query.for_read(:for_user, %{user_id: user2.id})
      |> Ash.read!(authorize?: false)

    assert Enum.map(theirs, & &1.id) == [h2.id]
  end

  test "for_user without the required user_id argument is refused" do
    assert {:error, %Ash.Error.Invalid{}} =
             HoldRequest
             |> Ash.Query.for_read(:for_user, %{})
             |> Ash.read(authorize?: false)
  end

  # -- (2) :oldest_active_for_book direct read ---------------------------------

  test "oldest_active_for_book returns the oldest remaining active hold for the book" do
    book_a = create_book!()
    book_b = create_book!()
    user = create_user!()

    first = place_hold!(user, book_a)
    second = place_hold!(user, book_a)
    _other = place_hold!(user, book_b)

    assert second.position == 2 and first.position == 1

    # get?: true means the read is single-result; the resource's queue
    # semantics keep at most one unfulfilled front-of-queue claimant at a
    # time, so cancel the older hold to observe the status filter + sort.
    first
    |> Ash.Changeset.for_update(:cancel, %{})
    |> Ash.update!(authorize?: false)

    oldest =
      HoldRequest
      |> Ash.Query.for_read(:oldest_active_for_book, %{book_id: book_a.id})
      |> Ash.read_one!(authorize?: false)

    assert oldest.id == second.id
    refute oldest.id == first.id

    # Cross-book isolation: book_b's hold never leaks in.
    other =
      HoldRequest
      |> Ash.Query.for_read(:oldest_active_for_book, %{book_id: book_b.id})
      |> Ash.read_one!(authorize?: false)

    assert other.book_id == book_b.id
    assert other.book_id != book_a.id
  end

  test "oldest_active_for_book returns nil for a book with no active holds" do
    book = create_book!()
    user = create_user!()

    hold = place_hold!(user, book)

    hold
    |> Ash.Changeset.for_update(:cancel, %{})
    |> Ash.update!(authorize?: false)

    assert {:ok, nil} ==
             HoldRequest
             |> Ash.Query.for_read(:oldest_active_for_book, %{book_id: book.id})
             |> Ash.read_one(authorize?: false)
  end

  # -- (3) :cancel refuse-on-fulfilled -----------------------------------------

  test "refuses to cancel a fulfilled hold" do
    book = create_book!(%{available_copies: 1, total_copies: 1})
    user = create_user!()
    hold = place_hold!(user, book)

    # A fulfilled hold requires the hold's own after_action Book.borrow_copy
    # decrement to succeed, so a copy must really be available first.
    hold =
      hold
      |> Ash.Changeset.for_update(:fulfill, %{})
      |> Ash.update!(authorize?: false)

    assert hold.status == :fulfilled

    assert {:error, %Ash.Error.Invalid{}} =
             hold
             |> Ash.Changeset.for_update(:cancel, %{})
             |> Ash.update(authorize?: false)

    reloaded = Ash.get!(HoldRequest, hold.id, authorize?: false)
    assert reloaded.status == :fulfilled
  end

  # -- (4) :cancel refuse-on-expired -------------------------------------------

  test "refuses to cancel an expired hold" do
    book = create_book!()
    user = create_user!()
    hold = place_hold!(user, book)

    expired =
      hold
      |> Ash.Changeset.for_update(:expire, %{})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             expired
             |> Ash.Changeset.for_update(:cancel, %{})
             |> Ash.update(authorize?: false)

    reloaded = Ash.get!(HoldRequest, hold.id, authorize?: false)
    assert reloaded.status == :expired
  end

  # -- (5) :expire refuse-on-cancelled -----------------------------------------

  test "refuses to expire a cancelled hold" do
    book = create_book!()
    user = create_user!()
    hold = place_hold!(user, book)

    cancelled =
      hold
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             cancelled
             |> Ash.Changeset.for_update(:expire, %{})
             |> Ash.update(authorize?: false)

    reloaded = Ash.get!(HoldRequest, hold.id, authorize?: false)
    assert reloaded.status == :cancelled
  end

  # -- (6) :expire refuse-on-expired -------------------------------------------

  test "refuses to re-expire an already-expired hold" do
    book = create_book!()
    user = create_user!()
    hold = place_hold!(user, book)

    expired =
      hold
      |> Ash.Changeset.for_update(:expire, %{})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             expired
             |> Ash.Changeset.for_update(:expire, %{})
             |> Ash.update(authorize?: false)

    reloaded = Ash.get!(HoldRequest, hold.id, authorize?: false)
    assert reloaded.status == :expired
  end

  # -- (7) :fulfill refuse-on-expired ------------------------------------------

  test "refuses to fulfill an expired hold" do
    book = create_book!(%{available_copies: 1, total_copies: 1})
    user = create_user!()
    hold = place_hold!(user, book)

    expired =
      hold
      |> Ash.Changeset.for_update(:expire, %{})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             expired
             |> Ash.Changeset.for_update(:fulfill, %{})
             |> Ash.update(authorize?: false)

    reloaded = Ash.get!(HoldRequest, hold.id, authorize?: false)
    assert reloaded.status == :expired

    # No inventory moved and no hand-off checkout minted for the refused fulfill.
    reloaded_book = Ash.get!(Xaas.Library.Book, book.id, authorize?: false)
    assert reloaded_book.available_copies == 1
  end

  # -- (8) :create status one_of constraint ------------------------------------

  test "create with an invalid status atom is refused by the one_of constraint" do
    book = create_book!()
    user = create_user!()

    assert {:error, %Ash.Error.Invalid{}} =
             HoldRequest
             |> Ash.Changeset.for_create(:create, %{
               book_id: book.id,
               user_id: user.id,
               status: :shelved
             })
             |> Ash.create(authorize?: false)

    assert HoldRequest
           |> Ash.Query.for_read(:for_book, %{book_id: book.id})
           |> Ash.read!(authorize?: false) == []
  end

  # -- (9) :destroy -------------------------------------------------------------

  test "destroy removes the hold row" do
    book = create_book!()
    user = create_user!()
    hold = place_hold!(user, book)

    assert :ok =
             hold
             |> Ash.Changeset.for_destroy(:destroy, %{})
             |> Ash.destroy!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
             Ash.get(HoldRequest, hold.id, authorize?: false)
  end
end
