defmodule Xaas.Library.CheckoutActuationTest do
  @moduledoc """
  Chicago-style qualification proving `Checkout.borrow` is safe to retry when
  routed through `Xaas.Actuation.run/4` with a deterministic idempotency key
  (`book_id:user_id:school_id`), matching `Xaas.Marketplace.Provider
  .actuate_status`'s pattern (see `lib/xaas/actuation.ex`).

  Real Ash resources, real Reactor, real sandboxed Postgres -- no mocks.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.{Book, Checkout}
  alias Xaas.Operations.ActuationReceipt

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user! do
    Xaas.Generator.create_user!()
  end

  # This file's own default (total_copies == available_copies, i.e. no
  # extra unavailable copies) differs deliberately from
  # Xaas.Generator.create_book!/1's general default (total_copies: 2
  # fixed) -- these tests need the book's total inventory to track
  # whatever available_copies they pass in.
  defp create_book!(available_copies) do
    Xaas.Generator.create_book!(%{
      available_copies: available_copies,
      total_copies: available_copies
    })
  end

  defp idempotency_key(book_id, user_id, school_id),
    do: "checkout:#{book_id}:#{user_id}:#{school_id}"

  test "duplicate Checkout.borrow with the same idempotency key does not double-decrement available_copies" do
    user = create_user!()
    book = create_book!(2)
    school_id = "willow-creek"
    key = idempotency_key(book.id, user.id, school_id)

    params = %{book_id: book.id, user_id: user.id, school_id: school_id}

    assert {:ok, first} =
             Xaas.Actuation.run(Checkout, :borrow, params,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "checkout_actuation_test"}
             )

    assert first.status == :succeeded
    refute first.replay?

    book_after_first = Ash.get!(Book, book.id, authorize?: false)
    assert book_after_first.available_copies == 1

    receipts_before = Ash.read!(ActuationReceipt, authorize?: false)

    assert {:ok, second} =
             Xaas.Actuation.run(Checkout, :borrow, params,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "checkout_actuation_test"}
             )

    assert second.status == :replayed
    assert second.replay?
    assert second.receipt.id == first.receipt.id
    assert length(Ash.read!(ActuationReceipt, authorize?: false)) == length(receipts_before)

    book_after_second = Ash.get!(Book, book.id, authorize?: false)
    assert book_after_second.available_copies == 1

    assert Ash.count!(Checkout, authorize?: false) == 1
  end

  test "same book+user+school but a different idempotency key is a distinct borrow (real double-decrement, not a bug)" do
    user = create_user!()
    book = create_book!(2)
    school_id = "willow-creek"

    params = %{book_id: book.id, user_id: user.id, school_id: school_id}

    assert {:ok, %{status: :succeeded}} =
             Xaas.Actuation.run(Checkout, :borrow, params,
               idempotency_key: idempotency_key(book.id, user.id, school_id) <> "-a",
               authorize?: false,
               authority: %{kind: "test_authority"}
             )

    assert {:ok, %{status: :succeeded}} =
             Xaas.Actuation.run(Checkout, :borrow, params,
               idempotency_key: idempotency_key(book.id, user.id, school_id) <> "-b",
               authorize?: false,
               authority: %{kind: "test_authority"}
             )

    assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0
    assert Ash.count!(Checkout, authorize?: false) == 2
  end
end
