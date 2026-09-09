defmodule Xaas.Library.HoldRequestTest do
  @moduledoc """
  Chicago-school test suite for Xaas.Library.HoldRequest lifecycle: place, fulfill, cancel,
  expire. Executes against real Postgres via the Sandbox, real Ash actions, zero mocks.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Library.{Book, HoldRequest}
  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  # Xaas.Accounts.User currently declares a `grade_level` attribute
  # (lib/xaas/accounts/user.ex) with no matching `users` table column yet --
  # a pre-existing, out-of-scope schema drift from concurrent work on that
  # resource this session (unrelated to hold lifecycle logic; confirmed by
  # the same failure in test/xaas/library/next_read_test.exs). Ash.Seed/Ash.create
  # against Xaas.Accounts.User selects that column and fails with
  # `column "grade_level" does not exist`. HoldRequest only needs a real
  # user_id foreign key, so this test suite creates the row directly against
  # the actual `users` table columns via a raw SQL insert, bypassing the
  # drifted Ash resource entirely -- this is a real Postgres row, not a mock.
  defp create_user!(email \\ nil) do
    id = Ecto.UUID.generate()
    email = email || Faker.Internet.email()

    %Postgrex.Result{rows: [[id, email]]} =
      Ecto.Adapters.SQL.query!(
        Xaas.Repo,
        "INSERT INTO users (id, email) VALUES ($1, $2) RETURNING id, email",
        [Ecto.UUID.dump!(id), email]
      )

    %{id: Ecto.UUID.load!(id), email: email}
  end

  defp create_book!(attrs) do
    available_copies = Map.get(attrs, :available_copies, 0)
    total_copies = Map.get(attrs, :total_copies, max(available_copies, 1))

    Book
    |> Ash.Changeset.for_create(:create, %{
      title: Map.get(attrs, :title, Faker.Commerce.product_name()),
      author: Map.get(attrs, :author, Faker.Person.name()),
      isbn: Faker.Commerce.color() <> "-#{System.unique_integer([:positive])}",
      grade_level: 5,
      genres: ["Fiction"],
      synopsis: "A book.",
      available_copies: available_copies,
      total_copies: total_copies
    })
    |> Ash.create!(authorize?: false)
  end

  defp place_hold!(user, book) do
    HoldRequest
    |> Ash.Changeset.for_create(:place, %{user_id: user.id, book_id: book.id})
    |> Ash.create!(authorize?: false)
  end

  describe "place" do
    test "places an active hold on a book with zero available copies" do
      book = create_book!(%{available_copies: 0})
      user = create_user!()

      hold = place_hold!(user, book)

      assert hold.status == :active
      assert hold.position == 1
      assert hold.book_id == book.id
      assert hold.user_id == user.id
      assert %DateTime{} = hold.expires_at
      assert DateTime.compare(hold.expires_at, DateTime.utc_now()) == :gt
    end

    test "queues successive holds on the same book behind each other by position" do
      book = create_book!(%{available_copies: 0})
      user1 = create_user!()
      user2 = create_user!()
      user3 = create_user!()

      hold1 = place_hold!(user1, book)
      hold2 = place_hold!(user2, book)
      hold3 = place_hold!(user3, book)

      assert hold1.position == 1
      assert hold2.position == 2
      assert hold3.position == 3
    end

    test "does not let a cancelled hold affect the next queue position" do
      book = create_book!(%{available_copies: 0})
      user1 = create_user!()
      user2 = create_user!()

      hold1 = place_hold!(user1, book)

      hold1
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)

      hold2 = place_hold!(user2, book)

      assert hold2.position == 1
    end
  end

  describe "fulfill" do
    test "fulfills an active hold and hands the newly-returned copy to the reader" do
      book = create_book!(%{available_copies: 0, total_copies: 1})
      user = create_user!()
      hold = place_hold!(user, book)

      # Simulate the copy being returned, making it available for the hold to claim.
      book
      |> Ash.Changeset.for_update(:return_copy, %{})
      |> Ash.update!(authorize?: false)

      fulfilled =
        hold
        |> Ash.Changeset.for_update(:fulfill, %{})
        |> Ash.update!(authorize?: false)

      assert fulfilled.status == :fulfilled
      assert %DateTime{} = fulfilled.fulfilled_at

      reloaded_book = Ash.get!(Book, book.id, authorize?: false)
      assert reloaded_book.available_copies == 0
    end

    test "refuses to fulfill a hold that is already fulfilled" do
      book = create_book!(%{available_copies: 0})
      user = create_user!()
      hold = place_hold!(user, book)

      # :fulfill's own after_action calls Book.borrow_copy (an atomic
      # decrement guarded by available_copies > 0, see book.ex) -- so a
      # copy must actually become available first, same as the sibling
      # "fulfills an active hold" test above, or even this first (valid)
      # fulfill call raises before the test reaches its real target: the
      # second, already-fulfilled call refused below.
      book
      |> Ash.Changeset.for_update(:return_copy, %{})
      |> Ash.update!(authorize?: false)

      fulfilled =
        hold
        |> Ash.Changeset.for_update(:fulfill, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               fulfilled
               |> Ash.Changeset.for_update(:fulfill, %{})
               |> Ash.update(authorize?: false)
    end

    test "refuses to fulfill a cancelled hold" do
      book = create_book!(%{available_copies: 0})
      user = create_user!()
      hold = place_hold!(user, book)

      cancelled =
        hold
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               cancelled
               |> Ash.Changeset.for_update(:fulfill, %{})
               |> Ash.update(authorize?: false)
    end
  end

  describe "cancel" do
    test "cancels an active hold and records cancelled_at" do
      book = create_book!(%{available_copies: 0})
      user = create_user!()
      hold = place_hold!(user, book)

      cancelled =
        hold
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update!(authorize?: false)

      assert cancelled.status == :cancelled
      assert %DateTime{} = cancelled.cancelled_at
    end

    test "refuses to cancel an already-cancelled hold" do
      book = create_book!(%{available_copies: 0})
      user = create_user!()
      hold = place_hold!(user, book)

      cancelled =
        hold
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               cancelled
               |> Ash.Changeset.for_update(:cancel, %{})
               |> Ash.update(authorize?: false)
    end
  end

  describe "expire" do
    test "expires an active hold whose expiration has passed" do
      book = create_book!(%{available_copies: 0})
      user = create_user!()
      hold = place_hold!(user, book)

      past = DateTime.add(DateTime.utc_now(), -60, :second)

      hold =
        hold
        |> Ash.Changeset.for_update(:update, %{})
        |> Ash.Changeset.force_change_attribute(:expires_at, past)
        |> Ash.update!(authorize?: false)

      expired =
        hold
        |> Ash.Changeset.for_update(:expire, %{})
        |> Ash.update!(authorize?: false)

      assert expired.status == :expired
    end

    test "the expirable read action finds only active holds past their expiration" do
      book = create_book!(%{available_copies: 0})
      user1 = create_user!()
      user2 = create_user!()

      past = DateTime.add(DateTime.utc_now(), -60, :second)

      stale_hold = place_hold!(user1, book)

      stale_hold =
        stale_hold
        |> Ash.Changeset.for_update(:update, %{})
        |> Ash.Changeset.force_change_attribute(:expires_at, past)
        |> Ash.update!(authorize?: false)

      fresh_hold = place_hold!(user2, book)

      expirable_ids =
        HoldRequest
        |> Ash.Query.for_read(:expirable)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)

      assert stale_hold.id in expirable_ids
      refute fresh_hold.id in expirable_ids
    end

    test "refuses to expire a fulfilled hold" do
      book = create_book!(%{available_copies: 0})
      user = create_user!()
      hold = place_hold!(user, book)

      # See the "already fulfilled" test above -- :fulfill needs a real
      # available copy for its own Book.borrow_copy decrement to succeed.
      book
      |> Ash.Changeset.for_update(:return_copy, %{})
      |> Ash.update!(authorize?: false)

      fulfilled =
        hold
        |> Ash.Changeset.for_update(:fulfill, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               fulfilled
               |> Ash.Changeset.for_update(:expire, %{})
               |> Ash.update(authorize?: false)
    end
  end

  describe "for_book and active reads" do
    test "for_book filters holds by book_id and active filters by status" do
      book1 = create_book!(%{available_copies: 0})
      book2 = create_book!(%{available_copies: 0})
      user = create_user!()

      hold1 = place_hold!(user, book1)
      _hold2 = place_hold!(create_user!(), book2)

      hold1
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)

      book1_holds =
        HoldRequest
        |> Ash.Query.for_read(:for_book, %{book_id: book1.id})
        |> Ash.read!(authorize?: false)

      assert length(book1_holds) == 1

      active_holds =
        HoldRequest
        |> Ash.Query.for_read(:active)
        |> Ash.read!(authorize?: false)

      assert Enum.all?(active_holds, &(&1.status == :active))
      refute Enum.any?(active_holds, &(&1.id == hold1.id))
    end
  end
end
