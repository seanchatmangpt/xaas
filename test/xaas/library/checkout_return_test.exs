defmodule Xaas.Library.CheckoutReturnTest do
  @moduledoc """
  Chicago-style test proving `Checkout.return` marks a checkout returned AND
  atomically increments the associated book's `available_copies` via
  `Book.return_copy` (through `Xaas.Library.Changes.IncrementBookInventory`).

  Real Ash resources, real sandboxed Postgres -- no mocks.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.{Book, Checkout}

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
  # Xaas.Generator.create_book!/1's own default (2/2), so each test can
  # assert exact copy counts through borrow/return.
  defp create_book!(available_copies) do
    Xaas.Generator.create_book!(%{
      available_copies: available_copies,
      total_copies: available_copies
    })
  end

  # Real actor, not `authorize?: false`: Checkout's own policy
  # (`policy action_type([:create, :update, :destroy])` ->
  # `authorize_if actor_present()`, lib/xaas/library/checkout.ex) already
  # authorizes any real, resolved actor -- passing one here (instead of
  # bypassing the policy entirely) means these tests also prove the real
  # borrower/returner path is reachable under the resource's real policy,
  # not just that the business logic works when authorization is
  # skipped.
  defp borrow!(book, user) do
    Checkout
    |> Ash.Changeset.for_create(:borrow, %{
      book_id: book.id,
      user_id: user.id,
      school_id: "willow-creek"
    })
    |> Ash.create!(actor: user)
  end

  test "Checkout.return marks the checkout returned and increments the book's available_copies" do
    user = create_user!()
    book = create_book!(2)

    checkout = borrow!(book, user)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1

    returned =
      checkout
      |> Ash.Changeset.for_update(:return, %{})
      |> Ash.update!(actor: user)

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

    checkout_a |> Ash.Changeset.for_update(:return, %{}) |> Ash.update!(actor: user_a)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1

    checkout_b |> Ash.Changeset.for_update(:return, %{}) |> Ash.update!(actor: user_b)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 2
  end

  test "the generic :update action does not touch available_copies (only :return does)" do
    user = create_user!()
    book = create_book!(2)

    checkout = borrow!(book, user)
    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1

    checkout
    |> Ash.Changeset.for_update(:update, %{status: :returned, returned_at: DateTime.utc_now()})
    |> Ash.update!(actor: user)

    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1
  end
end
