defmodule Xaas.Library.CheckoutResourceCourtW984jiTest do
  @moduledoc """
  W984ji unclaimed-family probe: the Checkout resource's OWN action layer,
  independent of the return/hold cascade (courted by W984eh) and the
  circulation flows (borrow cap, double-return, hold fulfillment -- already
  deepened by W796/W809/W902 courts). Census of
  `lib/xaas/library/checkout.ex` against `test/` found these genuinely
  unexercised, state-bearing branches:

  1. `:destroy` -- listed in `defaults([:read, :destroy])` and named in the
     mutation policy, but no test ever calls Ash.destroy on a Checkout. The
     deny-by-default floor (guest denied, real actor admitted) is asserted
     in comments everywhere and proven nowhere on this action.
  2. `status` one_of constraint (`[:borrowed, :returned, :overdue]`) --
     every fixture mints a legal status; nothing proves the constraint
     refuses an out-of-family value on :create or :update.
  3. `belongs_to` `allow_nil?(false)` on book/user -- nothing creates a
     Checkout missing user_id/book_id; the required-attribute refusal is
     unproven.
  4. `:for_user` argument `allow_nil?(false)` -- only the happy path is
     driven (checkout_policy_deepening_test.exs:76); omitting user_id is
     unexercised.
  5. plain `:create` attribute defaults (school_id "willow-creek",
     borrowed_at now, renewed_count 0, status :borrowed) -- every existing
     test supplies them via :borrow or explicit fixture; the default path
     persists state no test has ever read back from a bare :create.

  No mocks. Real sandboxed Postgres via Xaas.DataCase. Chicago-style:
  assert on final persisted state, not call counts.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.Checkout

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!, do: Xaas.Generator.create_user!()

  defp create_book! do
    Xaas.Generator.create_book!(%{available_copies: 2, total_copies: 2})
  end

  defp create_checkout!(user, book) do
    Checkout
    |> Ash.Changeset.for_create(:create, %{
      book_id: book.id,
      user_id: user.id,
      school_id: "willow-creek"
    })
    |> Ash.create!(actor: user)
  end

  # -- (1) :destroy policy floor ---------------------------------------------

  test "destroying a checkout with no actor is forbidden (deny-by-default floor)" do
    # Mutation rationale: deleting `authorize_if(actor_present())` from the
    # create/update/destroy policy would let a guest persona (actor: nil)
    # erase circulation history; this assertion is the only proof in the
    # tree that :destroy is behind the actor floor.
    user = create_user!()
    book = create_book!()
    checkout = create_checkout!(user, book)

    persisted = Ash.get!(Checkout, checkout.id, authorize?: false)

    assert {:error, %Ash.Error.Forbidden{}} =
             persisted
             |> Ash.Changeset.for_destroy(:destroy, %{})
             |> Ash.destroy(actor: nil)

    assert Ash.get!(Checkout, checkout.id, authorize?: false).id == checkout.id
  end

  test "a real actor can destroy a checkout and the row is gone" do
    # Mutation rationale: removing :destroy from the action surface (or from
    # defaults) would break the admitted actor path; asserting the persisted
    # absence of the row proves the action is live end to end.
    user = create_user!()
    book = create_book!()
    checkout = create_checkout!(user, book)

    persisted = Ash.get!(Checkout, checkout.id, authorize?: false)

    assert :ok =
             persisted
             |> Ash.Changeset.for_destroy(:destroy, %{})
             |> Ash.destroy!(actor: user)

    assert {:error, _} = Ash.get(Checkout, checkout.id, authorize?: false)
  end

  # -- (2) status one_of constraint ------------------------------------------

  test "creating a checkout with an out-of-family status is refused typed" do
    # Mutation rationale: widening the one_of (or dropping the constraint)
    # would admit statuses no circulation code understands (e.g. :lost);
    # this is the only test pinning the constraint on :create.
    user = create_user!()
    book = create_book!()

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Checkout
             |> Ash.Changeset.for_create(:create, %{
               book_id: book.id,
               user_id: user.id,
               school_id: "willow-creek",
               status: :lost
             })
             |> Ash.create(actor: user)

    assert Enum.any?(errors, &(&1.field == :status))
  end

  test "updating a checkout to an out-of-family status is refused typed" do
    # Mutation rationale: the :update accept list exposes :status directly;
    # a constraint regression would let a generic update mint an
    # unrepresentable state that :return's open-guard would then mis-handle.
    user = create_user!()
    book = create_book!()
    checkout = create_checkout!(user, book)

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             checkout
             |> Ash.Changeset.for_update(:update, %{status: :mysteriously_vanished})
             |> Ash.update(actor: user)

    assert Enum.any?(errors, &(&1.field == :status))
  end

  # -- (3) belongs_to allow_nil?(false) --------------------------------------

  test "creating a checkout without user_id is refused typed" do
    # Mutation rationale: flipping allow_nil?(false) off the user
    # belongs_to would admit orphan checkouts that no reader can be charged
    # for and that the borrow cap (user_id-scoped) can never see.
    user = create_user!()
    book = create_book!()

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Checkout
             |> Ash.Changeset.for_create(:create, %{
               book_id: book.id,
               school_id: "willow-creek"
             })
             |> Ash.create(actor: user)

    assert Enum.any?(errors, &(&1.field == :user_id))
  end

  test "creating a checkout without book_id is refused typed" do
    # Mutation rationale: without the book reference, inventory
    # decrement/increment changes (:borrow/:return) would target nothing;
    # this proves the required reference cannot be silently omitted.
    user = create_user!()
    book = create_book!()

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Checkout
             |> Ash.Changeset.for_create(:create, %{
               user_id: user.id,
               school_id: "willow-creek"
             })
             |> Ash.create(actor: user)

    assert Enum.any?(errors, &(&1.field == :book_id))
  end

  # -- (4) :for_user missing-argument branch ---------------------------------

  test "for_user without the required user_id argument is refused" do
    # Mutation rationale: relaxing allow_nil?(false) on the argument would
    # turn the scoped read into an unscoped all-checkouts read; the
    # argument-required refusal is the guard nobody has ever tripped.
    user = create_user!()

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Checkout
             |> Ash.Query.for_read(:for_user, %{})
             |> Ash.read(actor: user)

    assert Enum.any?(errors, &(&1.field == :user_id))
  end

  # -- (5) plain :create attribute defaults ----------------------------------

  test "bare :create persists the attribute defaults (school, borrowed_at, renewed_count, status)" do
    # Mutation rationale: dropping any default (school_id "willow-creek",
    # borrowed_at now, renewed_count 0, status :borrowed) would mint rows
    # with nil/absent state that every downstream reader assumes; every
    # existing test supplies these values explicitly through :borrow, so
    # the default path itself has never been read back.
    user = create_user!()
    book = create_book!()

    checkout =
      Checkout
      |> Ash.Changeset.for_create(:create, %{
        book_id: book.id,
        user_id: user.id
      })
      |> Ash.create!(actor: user)

    reloaded = Ash.get!(Checkout, checkout.id, authorize?: false)
    assert reloaded.school_id == "willow-creek"
    assert reloaded.status == :borrowed
    assert reloaded.renewed_count == 0
    assert %DateTime{} = reloaded.borrowed_at
  end
end
