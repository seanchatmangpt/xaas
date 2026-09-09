defmodule Xaas.Library.CheckoutReturnTest do
  @moduledoc """
  Chicago-style test proving `Checkout.return` marks a checkout returned AND
  atomically increments the associated book's `available_copies` via
  `Book.return_copy` (through `Xaas.Library.Changes.IncrementBookInventory`).

  Real Ash resources, real sandboxed Postgres -- no mocks.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Checkout}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user! do
    Ash.Seed.seed!(User, %{email: Faker.Internet.email()})
  end

  defp create_book!(available_copies) do
    title = Faker.Commerce.product_name()

    Book
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      author: Faker.Person.name(),
      isbn: "isbn-#{System.unique_integer([:positive])}",
      grade_level: 4,
      genres: ["Fiction"],
      synopsis: "test synopsis",
      available_copies: available_copies,
      total_copies: available_copies
    })
    |> Ash.create!(authorize?: false)
  end

  defp borrow!(book, user) do
    Checkout
    |> Ash.Changeset.for_create(:borrow, %{book_id: book.id, user_id: user.id, school_id: "willow-creek"})
    |> Ash.create!(authorize?: false)
  end

  test "Checkout.return marks the checkout returned and increments the book's available_copies" do
    user = create_user!()
    book = create_book!(2)

    checkout = borrow!(book, user)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1

    returned =
      checkout
      |> Ash.Changeset.for_update(:return, %{})
      |> Ash.update!(authorize?: false)

    assert returned.status == :returned
    assert %DateTime{} = returned.returned_at

    book_after_return = Ash.get!(Book, book.id, authorize?: false)
    assert book_after_return.available_copies == 2
  end

  test "returning two separate checkouts for the same book increments available_copies for each" do
    user_a = create_user!()
    user_b = create_user!()
    book = create_book!(2)

    checkout_a = borrow!(book, user_a)
    checkout_b = borrow!(book, user_b)

    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0

    checkout_a |> Ash.Changeset.for_update(:return, %{}) |> Ash.update!(authorize?: false)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1

    checkout_b |> Ash.Changeset.for_update(:return, %{}) |> Ash.update!(authorize?: false)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 2
  end

  test "the generic :update action does not touch available_copies (only :return does)" do
    user = create_user!()
    book = create_book!(2)

    checkout = borrow!(book, user)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1

    checkout
    |> Ash.Changeset.for_update(:update, %{status: :returned, returned_at: DateTime.utc_now()})
    |> Ash.update!(authorize?: false)

    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1
  end
end
