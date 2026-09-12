defmodule Xaas.Library.Reactors.Steps.ScoreBook do
  @moduledoc """
  Step module for scoring an individual book inside Reactor map steps.
  """
  use Reactor.Step

  alias Xaas.Library.Embeddings

  @impl true
  def run(
        %{
          book: book,
          profile: profile,
          curated_book_ids: curated_ids,
          weights: weights,
          student_grade: student_grade
        } = args,
        _context,
        _options
      ) do
    accepted_book_ids = Map.get(args, :accepted_book_ids, MapSet.new())
    collab = compute_collab(book, profile.past_genres, accepted_book_ids)

    with {:ok, semantic} <- compute_semantic(book, profile.embedding) do
      grade_fit = compute_grade_fit(book.grade_level, student_grade)
      available = if book.available_copies > 0, do: 1.0, else: 0.0
      diversity = compute_diversity(book.genres, profile.past_genres)
      curation = if MapSet.member?(curated_ids, book.id), do: 1.0, else: 0.0

      score =
        weights.collab * collab +
          weights.semantic * semantic +
          weights.grade_fit * grade_fit +
          weights.available * available +
          weights.diversity * diversity +
          weights.curation * curation

      factors = %{
        collab: collab,
        semantic: semantic,
        grade_fit: grade_fit,
        available: available,
        diversity: diversity,
        curation: curation
      }

      {:ok, %{book: book, score: score, factors: factors}}
    end
  end

  # Mirrors Xaas.Library.Ranker's (private, procedural-path) compute_collab_score/3:
  # genre-overlap base score, boosted by +0.25 (capped at 1.0) when this exact book
  # was recommended to this user before in a RecommendationLog marked accepted --
  # the real collaborative-filtering acceptance signal, not a placeholder.
  defp compute_collab(book, past_genres, accepted_book_ids) do
    base_score =
      if map_size(past_genres) == 0 do
        0.5
      else
        book_genres = MapSet.new(book.genres || [])

        overlap =
          MapSet.intersection(MapSet.new(Map.keys(past_genres)), book_genres) |> MapSet.size()

        if MapSet.size(book_genres) > 0,
          do: min(1.0, overlap / MapSet.size(book_genres)),
          else: 0.5
      end

    if MapSet.member?(accepted_book_ids, book.id) do
      min(1.0, base_score + 0.25)
    else
      base_score
    end
  end

  defp compute_semantic(book, student_embedding) do
    case book.embedding do
      nil ->
        text = "#{book.title} #{book.synopsis} #{Enum.join(book.genres || [], " ")}"

        # Embeddings.embed/1 is total (pure Nx hashing, no failure path) -- see
        # Xaas.Library.Embeddings @spec. {:error, _} arm removed as dead code.
        {:ok, emb} = Embeddings.embed(text)
        {:ok, Embeddings.cosine_similarity(student_embedding, emb)}

      emb when is_list(emb) ->
        {:ok, Embeddings.cosine_similarity(student_embedding, emb)}

      %Ash.Vector{} = vec ->
        # Real fix: Book.embedding is now a real pgvector-backed Ash.Vector
        # (via the `vectorize` DSL, lib/xaas/library/book.ex) instead of a
        # plain list -- Ecto/AshPostgres loads it back as an %Ash.Vector{}
        # struct, not the list this function originally assumed. Mirrors
        # the same real fix already applied in
        # Xaas.Library.Ranker.compute_semantic_score/2.
        {:ok, Embeddings.cosine_similarity(student_embedding, Ash.Vector.to_list(vec))}
    end
  end

  defp compute_grade_fit(nil, _student_grade), do: 0.5
  defp compute_grade_fit(_book_grade, nil), do: 0.5

  defp compute_grade_fit(book_grade, student_grade) do
    bg = if is_struct(book_grade, Decimal), do: Decimal.to_integer(book_grade), else: book_grade

    sg =
      if is_struct(student_grade, Decimal),
        do: Decimal.to_integer(student_grade),
        else: student_grade

    if is_integer(bg) and is_integer(sg) do
      delta = abs(bg - sg)
      max(0.0, 1.0 - delta * 0.3)
    else
      0.5
    end
  end

  defp compute_diversity(book_genres, past_frequencies) do
    book_genres = book_genres || []

    if book_genres == [] do
      0.5
    else
      total_past = Enum.sum(Map.values(past_frequencies))

      if total_past == 0 do
        0.8
      else
        scores =
          Enum.map(book_genres, fn g ->
            count = Map.get(past_frequencies, g, 0)
            1.0 - min(1.0, count / total_past)
          end)

        Enum.sum(scores) / length(scores)
      end
    end
  end
end
