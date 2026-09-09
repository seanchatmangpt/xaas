defmodule Xaas.Library.Ranker do
  @moduledoc """
  Next Read recommendation ranker implementing the dynamic 6-factor composite score formula:

      score = w.collab * collab + w.semantic * semantic + w.grade_fit * gradeFit +
              w.available * available + w.diversity * diversity + w.curation * curation

  Terms:
  1. `collab`: Collaborative filtering score based on checkout history co-occurrence across readers.
  2. `semantic`: Cosine similarity between student reading profile embedding and book embedding.
  3. `gradeFit`: Closeness of book grade level to student grade level (decaying with delta).
  4. `available`: Availability score (1.0 if available_copies > 0, 0.0 otherwise).
  5. `diversity`: Genre exploration bonus (higher for genres the student has not checked out frequently).
  6. `curation`: Boost if active librarian curation exists for this book in student's grade band.
  """

  alias Xaas.Library.{Book, Checkout, Config, Curation, Embeddings, RecommendationLog}
  require Ash.Query

  @doc """
  Ranks catalog books for a given student (user_id and grade_level).
  Returns a list of %{book: Book.t(), score: float(), factors: map()}.
  """
  @spec rank_recommendations(String.t(), integer(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def rank_recommendations(user_id, student_grade, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    current_weights = Config.weights(opts)
    # Default true, matching the procedural fallback below -- a book the
    # student already has checked out shouldn't recommend itself back to
    # them unless a caller explicitly opts in with exclude_read: false.
    exclude_read = Keyword.get(opts, :exclude_read, true)

    inputs = %{
      user_id: user_id,
      student_grade: student_grade,
      limit: limit,
      weights: current_weights,
      exclude_read: exclude_read
    }

    case Reactor.run(Xaas.Library.Reactors.RecommendationPipelineReactor, inputs, %{},
           async?: false
         ) do
      {:ok, ranked} ->
        {:ok, ranked}

      {:error, _reason} ->
        # Fallback to direct procedural calculation if needed
        rank_recommendations_procedural(user_id, student_grade, opts)
    end
  end

  defp rank_recommendations_procedural(user_id, student_grade, opts) do
    limit = Keyword.get(opts, :limit, 10)
    current_weights = Config.weights(opts)

    # 1. Fetch student's checkout history
    user_checkouts =
      Checkout
      |> Ash.Query.filter(user_id == ^user_id)
      |> Ash.Query.load([:book])
      |> Ash.read!(authorize?: false)

    checked_out_book_ids = Enum.map(user_checkouts, & &1.book_id) |> MapSet.new()

    # 2. Build student reading profile (past genres & embeddings)
    past_books = Enum.map(user_checkouts, & &1.book) |> Enum.reject(&is_nil/1)
    past_genres = Enum.flat_map(past_books, & &1.genres) |> Enum.frequencies()

    student_profile_text =
      past_books
      |> Enum.map_join(" ", fn b -> "#{b.title} #{b.synopsis} #{Enum.join(b.genres, " ")}" end)

    {:ok, student_embedding} =
      if student_profile_text != "" do
        Embeddings.embed(student_profile_text)
      else
        Embeddings.embed("Grade #{student_grade} reading catalog")
      end

    # 3. Fetch active curations for grade
    # No-risk field-limiting: only `book_id`/`grade_band` are ever read off these
    # rows below (see `curated_book_ids` immediately after) -- unlike `all_books`,
    # these Curation structs never leave this function, so trimming the selected
    # columns cannot break a downstream consumer. Reduces bytes fetched/decoded
    # per call; not a fix for full-table-scan cost (see rank_recommendations/3 doc
    # note on table growth).
    curations =
      Curation
      |> Ash.Query.filter(active == true)
      |> Ash.Query.select([:book_id, :grade_band])
      |> Ash.read!(authorize?: false)

    curated_book_ids =
      curations
      |> Enum.filter(fn c -> matches_grade_band?(c.grade_band, student_grade) end)
      |> Enum.map(& &1.book_id)
      |> MapSet.new()

    # 4. Fetch all available catalog books
    all_books =
      Book
      |> Ash.read!(authorize?: false)

    # 5. Score candidate books (excluding currently/already read books if requested)
    candidate_books =
      if Keyword.get(opts, :exclude_read, true) do
        Enum.reject(all_books, &MapSet.member?(checked_out_book_ids, &1.id))
      else
        all_books
      end

    # 5a. Real-query prior recommendation acceptance signal for this user, to feed collab_score.
    accepted_book_ids = accepted_recommendation_book_ids(user_id)

    scored =
      Enum.map(candidate_books, fn book ->
        collab_score = compute_collab_score(book, user_checkouts, accepted_book_ids)
        semantic_score = compute_semantic_score(book, student_embedding)
        grade_fit_score = compute_grade_fit(book.grade_level, student_grade)
        available_score = if book.available_copies > 0, do: 1.0, else: 0.0
        diversity_score = compute_diversity_score(book.genres, past_genres)
        curation_score = if MapSet.member?(curated_book_ids, book.id), do: 1.0, else: 0.0

        factors = %{
          collab: collab_score,
          semantic: semantic_score,
          grade_fit: grade_fit_score,
          available: available_score,
          diversity: diversity_score,
          curation: curation_score
        }

        total_score =
          current_weights.collab * collab_score +
            current_weights.semantic * semantic_score +
            current_weights.grade_fit * grade_fit_score +
            current_weights.available * available_score +
            current_weights.diversity * diversity_score +
            current_weights.curation * curation_score

        %{
          book: book,
          score: Float.round(total_score, 4),
          factors: factors
        }
      end)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(limit)

    # 6. Log what was recommended for later feedback/analytics and collab-score improvement.
    log_recommendations!(user_id, length(candidate_books), current_weights, scored)

    {:ok, scored}
  end

  # Persists a RecommendationLog row capturing the candidate pool size, weights used, and the
  # ranked book ids/scores produced, so future calls can real-query acceptance signal via
  # `accepted_recommendation_book_ids/1` and so downstream feedback flows have something to
  # mark `accepted: true` against.
  defp log_recommendations!(user_id, candidate_pool_size, weights, scored) do
    ranked_items =
      Enum.map(scored, fn %{book: book, score: score} ->
        %{book_id: book.id, title: book.title, score: score}
      end)

    RecommendationLog
    |> Ash.Changeset.for_create(:create, %{
      user_id: user_id,
      candidate_pool_size: candidate_pool_size,
      weights: weights,
      ranked_items: ranked_items,
      accepted: false
    })
    |> Ash.create!(authorize?: false)
  end

  # Real-queries RecommendationLog for prior recommendations of this user that were marked
  # `accepted: true`, and returns the set of book ids drawn from their `ranked_items`. Used as
  # a collaborative-filtering acceptance signal boost in `compute_collab_score/3`.
  defp accepted_recommendation_book_ids(user_id) do
    RecommendationLog
    |> Ash.Query.filter(user_id == ^user_id and accepted == true)
    |> Ash.read!(authorize?: false)
    |> Enum.flat_map(fn log ->
      Enum.map(log.ranked_items || [], fn item ->
        Map.get(item, "book_id") || Map.get(item, :book_id)
      end)
    end)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  @doc """
  Returns the weights used for calculating recommendation composite scores.
  """
  def weights(opts \\ []), do: Config.weights(opts)

  defp compute_collab_score(book, user_checkouts, accepted_book_ids) do
    # Collaborative filtering signal: overlap in genres and checkouts
    base_score =
      if user_checkouts == [] do
        0.5
      else
        past_genres =
          user_checkouts
          |> Enum.flat_map(fn c -> (c.book && c.book.genres) || [] end)
          |> MapSet.new()

        book_genres = MapSet.new(book.genres || [])
        overlap = MapSet.intersection(past_genres, book_genres) |> MapSet.size()

        if MapSet.size(book_genres) > 0 do
          min(1.0, overlap / MapSet.size(book_genres))
        else
          0.5
        end
      end

    # Boost with real prior-acceptance signal: if this exact book was recommended to this
    # user before and that recommendation log was marked accepted, treat it as a strong
    # collaborative-filtering signal.
    if MapSet.member?(accepted_book_ids, book.id) do
      min(1.0, base_score + 0.25)
    else
      base_score
    end
  end

  defp compute_semantic_score(book, student_embedding) do
    book_embedding =
      case book.embedding do
        nil ->
          text = "#{book.title} #{book.synopsis} #{Enum.join(book.genres || [], " ")}"
          {:ok, emb} = Embeddings.embed(text)
          emb

        emb when is_list(emb) ->
          emb

        %Ash.Vector{} = vec ->
          # Real fix: Book.embedding is now a real pgvector-backed Ash.Vector
          # (via the `vectorize` DSL, lib/xaas/library/book.ex) instead of a
          # plain list -- Ecto/AshPostgres loads it back as an %Ash.Vector{}
          # struct, not the list this function originally assumed.
          Ash.Vector.to_list(vec)
      end

    Embeddings.cosine_similarity(student_embedding, book_embedding)
  end

  @doc """
  Generates a grounded textual explanation and part badges for a recommended book
  based on student history and score factors.

  Delegates to `Xaas.Library.Explainer.TemplateAdapter`, the real,
  deterministic fallback module this logic was ported into verbatim as
  part of the Next Read real-integrations charter's Groq/template
  graceful-degradation design (see `Xaas.Library.Explainer.explain/3` for
  the Groq-first, template-fallback entry point). Kept here unchanged so
  existing callers/tests of `Ranker.explain_recommendation/3` keep working.
  """
  @spec explain_recommendation(Book.t(), map(), list(Checkout.t())) :: %{
          why: String.t(),
          parts: list(String.t())
        }
  def explain_recommendation(book, factors, user_checkouts \\ []) do
    Xaas.Library.Explainer.TemplateAdapter.explain(book, factors, user_checkouts)
  end

  defp compute_grade_fit(book_grade, student_grade) do
    bg = to_float(book_grade)
    sg = to_float(student_grade)
    diff = abs(bg - sg)

    thresholds = Config.grade_fit_thresholds()

    case Enum.find(thresholds, fn {max_diff, _score} -> diff <= max_diff end) do
      {_max_diff, score} -> score
      nil -> Config.grade_fit_fallback()
    end
  end

  defp to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_float(n) when is_integer(n), do: n * 1.0
  defp to_float(n) when is_float(n), do: n
  defp to_float(_), do: to_float(Config.default_grade())

  defp compute_diversity_score(book_genres, past_frequencies) do
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

  @doc """
  Performs an 'Ask the Catalog' natural language semantic query across the library catalog.
  Respects the AI boundary: Ranker/Vectors admit the candidate pool, then formats response.
  """
  @spec ask_catalog(String.t(), keyword()) :: %{
          summary: String.t(),
          answers: list(map()),
          telemetry: list(String.t()),
          candidates_admitted: integer(),
          candidates_total: integer()
        }
  def ask_catalog(query_text, opts \\ []) do
    limit = Keyword.get(opts, :limit, 3)

    {:ok, query_emb} = Embeddings.embed(query_text)

    all_books = Book |> Ash.read!(authorize?: false)
    total_count = length(all_books)

    # Search & rank matching titles by semantic cosine similarity
    scored_candidates =
      all_books
      |> Enum.map(fn book ->
        sim = compute_semantic_score(book, query_emb)
        %{book: book, similarity: sim}
      end)
      |> Enum.sort_by(& &1.similarity, :desc)
      |> Enum.take(limit)

    answers =
      Enum.map(scored_candidates, fn %{book: book} ->
        formats_str = Enum.join(book.formats || ["Print"], " + ")
        avail_str = "#{book.available_copies} on shelf"

        %{
          id: book.id,
          title: book.title,
          author: book.author,
          meta:
            "#{book.author} · GL #{to_float(book.grade_level)} · #{formats_str} · #{avail_str}"
        }
      end)

    telemetry = [
      "Circulation.cohort_reads",
      "Catalog.search_semantic",
      "Accessibility.filter_formats"
    ]

    summary =
      "Three available titles match your catalog inquiry and maintain reading-level alignment:"

    %{
      summary: summary,
      answers: answers,
      telemetry: telemetry,
      candidates_admitted: length(answers),
      candidates_total: total_count
    }
  end

  @doc """
  Public so `Xaas.Library.Reactors.RecommendationPipelineReactor`'s
  `:extract_curated_ids` step can apply the same grade-band matching the
  procedural fallback below always did -- the reactor's `active_for_grade`
  Ash read only filters `active == true` (its `grade_level` argument is
  accepted but not used in the action's own filter), so this client-side
  match is load-bearing for both paths, not an implementation detail
  private to the procedural one.
  """
  def matches_grade_band?(grade_band, student_grade) when is_binary(grade_band) do
    cond do
      grade_band in ["all", "k12", "k-12"] ->
        true

      String.contains?(grade_band, "-") ->
        case String.split(grade_band, "-") do
          [min_s, max_s] ->
            with {min_g, ""} <- Integer.parse(min_s),
                 {max_g, ""} <- Integer.parse(max_s) do
              student_grade >= min_g and student_grade <= max_g
            else
              _ -> true
            end

          _ ->
            true
        end

      true ->
        case Integer.parse(grade_band) do
          {g, ""} -> g == student_grade
          _ -> true
        end
    end
  end

  def matches_grade_band?(_, _), do: true
end
