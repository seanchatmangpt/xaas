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
            book
            |> Ash.Changeset.for_update(:return_copy, %{})
            |> Ash.update(authorize?: false)

            {:ok, checkout}

          _ ->
            {:ok, checkout}
        end
      end)
    else
      changeset
    end
  end
end
