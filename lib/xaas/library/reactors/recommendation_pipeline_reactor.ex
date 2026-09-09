defmodule Xaas.Library.Reactors.RecommendationPipelineReactor do
  @moduledoc """
  Master Ash.Reactor pipeline orchestrating 6-factor recommendation scoring, candidate pool admission,
  and recommendation log generation with parallel execution, sub-reactor composition, map steps, and collect steps.
  """
  use Ash.Reactor

  require Ash.Query

  alias Xaas.Library.{Book, Checkout, Curation, RecommendationLog}
  alias Xaas.Library.Reactors.StudentProfileSubReactor

  ash do
    default_domain(Xaas.Library)
  end

  input(:user_id)
  input(:student_grade)
  input(:limit)
  input(:weights)
  input(:exclude_read)

  # 1. Query past checkouts for this user
  read :get_user_checkouts, Checkout, :for_user do
    inputs(%{user_id: input(:user_id)})
    load(value([:book]))
  end

  # 2. Query active curations for grade band
  read :get_active_curations, Curation, :active_for_grade do
    inputs(%{grade_level: input(:student_grade)})
  end

  # 3. Query all candidate books
  read(:get_all_books, Book, :read)

  # 3a. Query this user's prior accepted recommendations, for the real
  # collaborative-filtering acceptance-signal boost (mirrors
  # Xaas.Library.Ranker's procedural accepted_recommendation_book_ids/1).
  # A plain function step (not an Ash.Reactor `read`) because the filter
  # needs both `user_id` and `accepted == true`, and reactor `input/1`
  # templates aren't resolvable inside a `read` step's own `filter expr()`.
  step :extract_accepted_book_ids do
    argument(:user_id, input(:user_id))

    run(fn %{user_id: user_id}, _context ->
      ids =
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

      {:ok, ids}
    end)
  end

  # 4. Compose sub-reactor for student reading profile & vector embedding
  compose :student_profile, StudentProfileSubReactor do
    argument(:user_checkouts, result(:get_user_checkouts))
    argument(:student_grade, input(:student_grade))
  end

  # 5. Extract curated book IDs into a MapSet
  #
  # `Curation.active_for_grade`'s own filter is `active == true` only --
  # its `grade_level` argument is accepted but not applied in the Ash
  # action -- so grade-band matching (curation.grade_band vs the student's
  # grade) has to happen here, via the same
  # `Xaas.Library.Ranker.matches_grade_band?/2` the procedural fallback
  # uses. Dropping this step (as the reactor previously did) silently
  # treats every active curation as matching every grade.
  step :extract_curated_ids do
    argument(:curations, result(:get_active_curations))
    argument(:student_grade, input(:student_grade))

    run(fn %{curations: curations, student_grade: student_grade}, _context ->
      ids =
        curations
        |> Enum.filter(&Xaas.Library.Ranker.matches_grade_band?(&1.grade_band, student_grade))
        |> Enum.map(& &1.book_id)
        |> MapSet.new()

      {:ok, ids}
    end)
  end

  # 6. Score and rank candidate books
  step :score_and_rank_candidates do
    argument(:all_books, result(:get_all_books))
    argument(:checkouts, result(:get_user_checkouts))
    argument(:curated_ids, result(:extract_curated_ids))
    argument(:accepted_book_ids, result(:extract_accepted_book_ids))
    argument(:profile, result(:student_profile))
    argument(:weights, input(:weights))
    argument(:student_grade, input(:student_grade))
    argument(:limit, input(:limit))
    argument(:exclude_read, input(:exclude_read))

    run(fn %{
             all_books: books,
             checkouts: checkouts,
             curated_ids: curated_ids,
             accepted_book_ids: accepted_book_ids,
             profile: profile,
             weights: weights,
             student_grade: student_grade,
             limit: limit,
             exclude_read: exclude_read
           },
           _context ->
      checked_out_ids = checkouts |> Enum.map(& &1.book_id) |> MapSet.new()

      candidates =
        if exclude_read do
          Enum.reject(books, &MapSet.member?(checked_out_ids, &1.id))
        else
          books
        end

      scored =
        candidates
        |> Enum.map(fn book ->
          {:ok, scored_item} =
            Xaas.Library.Reactors.Steps.ScoreBook.run(
              %{
                book: book,
                profile: profile,
                curated_book_ids: curated_ids,
                accepted_book_ids: accepted_book_ids,
                weights: weights,
                student_grade: student_grade
              },
              %{},
              []
            )

          scored_item
        end)
        |> Enum.sort_by(& &1.score, :desc)
        |> Enum.take(limit)

      {:ok, %{scored: scored, candidate_pool_size: length(candidates)}}
    end)
  end

  # 7. Persist a RecommendationLog row for later feedback/analytics and for
  # `extract_accepted_book_ids`'s own future collab-score boost -- mirrors
  # Xaas.Library.Ranker's procedural log_recommendations!/4. Dropping this
  # (as the reactor previously did) silently breaks both the analytics
  # trail and the acceptance-signal loop above.
  step :log_recommendation do
    argument(:user_id, input(:user_id))
    argument(:weights, input(:weights))
    argument(:scoring, result(:score_and_rank_candidates))

    run(fn %{
             user_id: user_id,
             weights: weights,
             scoring: %{scored: scored, candidate_pool_size: pool_size}
           },
           _context ->
      ranked_items =
        Enum.map(scored, fn %{book: book, score: score} ->
          %{book_id: book.id, title: book.title, score: score}
        end)

      RecommendationLog
      |> Ash.Changeset.for_create(:create, %{
        user_id: user_id,
        candidate_pool_size: pool_size,
        weights: weights,
        ranked_items: ranked_items,
        accepted: false
      })
      |> Ash.create!(authorize?: false)

      {:ok, scored}
    end)
  end

  # 8. Debug step: introspect top candidate titles
  debug :log_recommendation_telemetry do
    argument(:top_items, result(:log_recommendation))
    argument(:message, value("[Reactor:RecommendationPipeline] Successfully ranked candidates"))
  end

  return(:log_recommendation)
end
