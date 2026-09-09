defmodule Xaas.Library.CheckoutConcurrencyTest do
  @moduledoc """
  Chicago-style qualification for a real race: two concurrent
  `Checkout.borrow` creates for the same book when `available_copies == 1`.

  Real finding this test guards against (fixed in
  `lib/xaas/library/changes/decrement_book_inventory.ex`): the `after_action`
  hook called `Ash.update(authorize?: false)` on `Book`'s atomic
  `:borrow_copy` action but discarded its result, always returning
  `{:ok, checkout}` regardless of whether the inventory decrement actually
  succeeded. `Book.borrow_copy` itself IS atomic at the DB level
  (`atomic_update(:available_copies, expr(available_copies - 1))` combined
  with `validate compare(:available_copies, greater_than: 0)`, which
  AshPostgres compiles into a single `UPDATE ... WHERE available_copies > 0
  RETURNING ...`), so under a real race only one of the two concurrent
  `:borrow_copy` updates can ever succeed. But the swallowed error meant BOTH
  `Checkout.borrow` creates still returned `{:ok, checkout}` -- silent
  overbooking: two `Checkout` rows recorded as borrowed for a book with only
  one copy, with the losing request's inventory decrement silently dropped.

  With the fix (bubbling the `:borrow_copy` error out of the `after_action`
  so the whole `:borrow` create rolls back and returns `{:error, ...}`),
  exactly one of the two concurrent `Checkout.borrow` creates succeeds and
  the book's `available_copies` lands at exactly 0, never negative and never
  silently wrong.

  Real Ash resources, real Reactor is NOT used here (plain `Ash.create`, not
  `Xaas.Actuation.run/4`) so the two racing requests are genuinely
  independent concurrent transactions, not deduplicated by an idempotency
  key -- that is the actual race this resource must defend against on its
  own, at the `:borrow_copy` atomic-update layer.
  """

  use Xaas.DataCase, async: false

  require Ash.Query

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Checkout, Embeddings}

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
    {:ok, embedding} = Embeddings.embed("#{title} test synopsis Fiction")

    Book
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      author: Faker.Person.name(),
      isbn: "isbn-#{System.unique_integer([:positive])}",
      grade_level: 4,
      genres: ["Fiction"],
      synopsis: "test synopsis",
      available_copies: available_copies,
      total_copies: available_copies,
      embedding: embedding
    })
    |> Ash.create!(authorize?: false)
  end

  test "two real concurrent Checkout.borrow creates for the last copy: exactly one succeeds" do
    user_a = create_user!()
    user_b = create_user!()
    book = create_book!(1)
    school_id = "willow-creek"

    params_a = %{book_id: book.id, user_id: user_a.id, school_id: school_id}
    params_b = %{book_id: book.id, user_id: user_b.id, school_id: school_id}

    task_a =
      Task.async(fn ->
        Checkout
        |> Ash.Changeset.for_create(:borrow, params_a, authorize?: false)
        |> Ash.create(authorize?: false)
      end)

    task_b =
      Task.async(fn ->
        Checkout
        |> Ash.Changeset.for_create(:borrow, params_b, authorize?: false)
        |> Ash.create(authorize?: false)
      end)

    results = Task.await_many([task_a, task_b], 10_000)

    successes = Enum.filter(results, &match?({:ok, _}, &1))
    failures = Enum.filter(results, &match?({:error, _}, &1))

    assert length(successes) == 1,
           "expected exactly one of the two concurrent borrows for the last copy to succeed, got: #{inspect(results)}"

    assert length(failures) == 1,
           "expected exactly one of the two concurrent borrows to fail (no copies available), got: #{inspect(results)}"

    reloaded = Ash.get!(Book, book.id, authorize?: false)
    assert reloaded.available_copies == 0

    real_checkout_count =
      Checkout
      |> Ash.read!(authorize?: false)
      |> Enum.count(&(&1.book_id == book.id))

    assert real_checkout_count == 1,
           "expected exactly one Checkout row to exist for the last copy, not an overbooked pair"
  end
end
