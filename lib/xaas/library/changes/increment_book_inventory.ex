defmodule Xaas.Library.Changes.IncrementBookInventory do
  @moduledoc """
  Ash change that atomically increments a book's available copies when a
  checkout is marked returned.
  """
  use Ash.Resource.Change
  alias Xaas.Library.Book

  @impl true
  def change(changeset, _opts, _context) do
    book_id = Ash.Changeset.get_attribute(changeset, :book_id)

    if book_id do
      Ash.Changeset.after_action(changeset, fn _changeset, checkout ->
        case Book |> Ash.get(book_id, authorize?: false) do
          {:ok, book} ->
            # Real result match, not a discarded call -- returning
            # `{:error, _}` from an `after_action` hook aborts the action
            # and rolls back its surrounding DB transaction (documented
            # Ash behavior). Previously this branch always returned
            # `{:ok, checkout}` regardless of whether the inner
            # `Book.return_copy` update actually succeeded, so a real
            # failure here was invisible to the caller and never rolled
            # back.
            case book
                 |> Ash.Changeset.for_update(:return_copy, %{})
                 |> Ash.update(authorize?: false) do
              {:ok, _book} -> {:ok, checkout}
              {:error, error} -> {:error, error}
            end

          {:error, error} ->
            {:error, error}
        end
      end)
    else
      changeset
    end
  end
end
