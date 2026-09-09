defmodule Xaas.Library.Reactors.CirculationBorrowReactorTest do
  @moduledoc """
  Chicago-style qualification for CirculationBorrowReactor -- real Ash
  resources, real Reactor, real sandboxed Postgres. Regression coverage for
  two real bugs found via a direct `Reactor.run/4` invocation (not by
  inspection): `:get_book` targeted a plain `:read` action Ash.Reactor's
  `read_one` step cannot filter by `:id` through (raised
  `Ash.Error.Invalid.NoSuchInput`), and both switch branches (`matches?`
  and `default`) were missing their own `return`, so a successful run
  still handed the caller `{:ok, nil}` instead of the real created record.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Checkout, HoldRequest}
  alias Xaas.Library.Reactors.CirculationBorrowReactor

  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user! do
    Ash.Seed.seed!(User, %{email: Faker.Internet.email()})
  end

  defp create_book!(available_copies) do
    Book
    |> Ash.Changeset.for_create(:create, %{
      title: "Circulation Reactor Fixture",
      author: Faker.Person.name(),
      isbn: "isbn-circ-#{System.unique_integer([:positive])}",
      grade_level: 6,
      genres: ["Fiction"],
      synopsis: "test synopsis",
      available_copies: available_copies,
      total_copies: max(available_copies, 1)
    })
    |> Ash.create!(authorize?: false)
  end

  test "available copies -> :matches? branch: creates a real Checkout and decrements inventory" do
    user = create_user!()
    book = create_book!(2)

    assert {:ok, %Checkout{} = checkout} =
             Reactor.run(
               CirculationBorrowReactor,
               %{book_id: book.id, user_id: user.id, school_id: "willow-creek", actor: user},
               %{},
               async?: false
             )

    assert checkout.book_id == book.id
    assert checkout.user_id == user.id
    assert checkout.status == :borrowed

    reloaded_book = Ash.get!(Book, book.id, authorize?: false)
    assert reloaded_book.available_copies == 1
  end

  test "zero copies -> default branch: creates a real active HoldRequest, no Checkout" do
    user = create_user!()
    book = create_book!(0)

    assert {:ok, %HoldRequest{} = hold} =
             Reactor.run(
               CirculationBorrowReactor,
               %{book_id: book.id, user_id: user.id, school_id: "willow-creek", actor: user},
               %{},
               async?: false
             )

    assert hold.book_id == book.id
    assert hold.user_id == user.id
    assert hold.status == :active

    checkouts =
      Checkout
      |> Ash.Query.filter(book_id == ^book.id)
      |> Ash.read!(authorize?: false)

    assert checkouts == []

    reloaded_book = Ash.get!(Book, book.id, authorize?: false)
    assert reloaded_book.available_copies == 0
  end
end
