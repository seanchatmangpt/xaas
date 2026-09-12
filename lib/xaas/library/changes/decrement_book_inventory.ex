defmodule Xaas.Library.Changes.DecrementBookInventory do
  @moduledoc """
  Ash change that atomically decrements a book's available copies upon checkout.
  """
  use Ash.Resource.Change
  alias Xaas.Library.Book

  @impl true
  def change(changeset, _opts, _context) do
    book_id = Ash.Changeset.get_attribute(changeset, :book_id)

    if book_id do
      Ash.Changeset.after_action(changeset, fn _changeset, checkout ->
        with {:ok, book} <- Book |> Ash.get(book_id, authorize?: false),
             {:ok, _book} <-
               book
               |> Ash.Changeset.for_update(:borrow_copy, %{})
               |> Ash.update(authorize?: false) do
          {:ok, checkout}
        else
          {:error, error} -> {:error, error}
        end
      end)
    else
      changeset
    end
  end
end
