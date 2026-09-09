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

  # Was previously a raw `Ecto.Adapters.SQL.query!` INSERT bypassing Ash
  # entirely, worked around a real schema drift: `Xaas.Accounts.User`
  # declared `grade_level` with no matching `users` column. That drift is
  # fixed (priv/repo/migrations/20260909064913_add_user_grade_level_school_id.exs
  # added the column; confirmed via a real `Ash.Seed.seed!/2` call
  # succeeding) -- delegates to the shared Xaas.Factory (real Ash path)
  # like every other test's `create_user!`, so a future Ash-level `User`
  # change (a default, a validation, a change hook) is no longer silently
  # skipped by this one file.
  defp create_user!(email \\ nil) do
    if email, do: Xaas.Factory.create_user!(%{email: email}), else: Xaas.Factory.create_user!()
  end

  # This file's own default (0 available copies) differs deliberately
  # from Xaas.Factory.create_book!/1's general default (2) -- most hold
  # tests specifically want "no copies," the precondition for a hold
  # queue existing at all.
  defp create_book!(attrs) do
    available_copies = Map.get(attrs, :available_copies, 0)

    Xaas.Factory.create_book!(
      Map.merge(attrs, %{
        available_copies: available_copies,
        total_copies: Map.get(attrs, :total_copies, max(available_copies, 1))
      })
    )
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
