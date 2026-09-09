defmodule Xaas.Library.Reactors.StudentProfileSubReactor do
  @moduledoc """
  Sub-reactor for computing student reading preferences and semantic profile embeddings.
  Demonstrates Reactor step, argument transformations, guard caching, and async execution.
  """
  use Reactor

  alias Xaas.Library.Embeddings

  input :user_checkouts
  input :student_grade

  step :extract_genres_and_text do
    argument :checkouts, input(:user_checkouts)
    argument :grade, input(:student_grade)

    run fn %{checkouts: checkouts, grade: grade}, _context ->
      past_books =
        checkouts
        |> Enum.map(& &1.book)
        |> Enum.reject(&is_nil/1)

      past_genres =
        past_books
        |> Enum.flat_map(&(&1.genres || []))
        |> Enum.frequencies()

      profile_text =
        case past_books do
          [] -> "Grade #{grade} reading catalog"
          books -> Enum.map_join(books, " ", fn b -> "#{b.title} #{b.synopsis} #{Enum.join(b.genres || [], " ")}" end)
        end

      {:ok, %{past_genres: past_genres, profile_text: profile_text, past_books: past_books}}
    end
  end

  step :compute_profile_embedding do
    argument :profile_data, result(:extract_genres_and_text)
    async? true

    run fn %{profile_data: %{profile_text: text, past_genres: genres, past_books: books}}, _context ->
      {:ok, embedding} = Embeddings.embed(text)
      {:ok, %{embedding: embedding, past_genres: genres, past_books: books}}
    end
  end

  return :compute_profile_embedding
end
