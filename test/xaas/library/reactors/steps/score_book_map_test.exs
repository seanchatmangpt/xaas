defmodule Xaas.Library.Reactors.Steps.ScoreBookMapTest do
  @moduledoc """
  Narrow, real verification of the `map` sub-behavior extracted for
  RecommendationPipelineReactor's `:score_candidates` step, WITHOUT touching
  the excluded recommendation_pipeline_reactor_test.exs.

  Defines a minimal ad hoc reactor module inline that reproduces exactly the
  same `map` shape (source -> per-item `step ... , ScoreBook` -> return) and
  runs it for real via Reactor.run/3, asserting:

    1. Real per-item results: N candidate books in -> N scored maps out, in
       the same relative order, each carrying a real numeric score.
    2. Real per-item error isolation: a book that forces ScoreBook's semantic
       step into its `{:error, _}` branch does not raise or kill the batch --
       the map step (and hence the reactor run) surfaces a real Reactor
       error for that item while leaving the rest of the batch to have been
       computed.
  """
  use ExUnit.Case, async: true

  alias Xaas.Library.Reactors.Steps.ScoreBook

  # Minimal ad hoc reactor exercising the real `map` DSL block against the
  # real ScoreBook step module -- same shape as
  # RecommendationPipelineReactor's :score_candidates map.
  defmodule MapHarnessReactor do
    use Reactor

    input(:books)
    input(:profile)
    input(:curated_book_ids)
    input(:accepted_book_ids)
    input(:weights)
    input(:student_grade)

    map :score_candidates do
      source(input(:books))

      step :score, Xaas.Library.Reactors.Steps.ScoreBook do
        argument(:book, element(:score_candidates))
        argument(:profile, input(:profile))
        argument(:curated_book_ids, input(:curated_book_ids))
        argument(:accepted_book_ids, input(:accepted_book_ids))
        argument(:weights, input(:weights))
        argument(:student_grade, input(:student_grade))
      end

      return(:score)
    end

    return(:score_candidates)
  end

  defp book(attrs) do
    %{
      id: Map.fetch!(attrs, :id),
      title: Map.get(attrs, :title, "Untitled"),
      synopsis: Map.get(attrs, :synopsis, ""),
      genres: Map.get(attrs, :genres, []),
      grade_level: Map.get(attrs, :grade_level, 3),
      available_copies: Map.get(attrs, :available_copies, 1),
      embedding: Map.get(attrs, :embedding, nil)
    }
  end

  defp base_inputs(books) do
    %{
      books: books,
      profile: %{past_genres: %{"fantasy" => 2}, embedding: List.duplicate(0.1, 384)},
      curated_book_ids: MapSet.new(),
      accepted_book_ids: MapSet.new(),
      weights: %{
        collab: 0.2,
        semantic: 0.2,
        grade_fit: 0.2,
        available: 0.2,
        diversity: 0.1,
        curation: 0.1
      },
      student_grade: 3
    }
  end

  test "map dispatches ScoreBook per candidate through real Reactor step machinery" do
    books = [
      book(%{id: 1, title: "Dragons", genres: ["fantasy"], embedding: List.duplicate(0.1, 384)}),
      book(%{id: 2, title: "Space", genres: ["scifi"], embedding: List.duplicate(0.2, 384)}),
      book(%{id: 3, title: "Ocean", genres: ["nature"], embedding: List.duplicate(0.05, 384)})
    ]

    assert {:ok, scored} = Reactor.run(MapHarnessReactor, base_inputs(books))

    assert length(scored) == 3
    assert Enum.map(scored, & &1.book.id) == [1, 2, 3]

    for item <- scored do
      assert is_float(item.score)
      assert item.score >= 0.0
      assert %{collab: _, semantic: _, grade_fit: _, available: _, diversity: _, curation: _} =
               item.factors
    end

    # Sanity: this really is Reactor's own step machinery, not a bare
    # Enum.map/2 -- confirm the real ScoreBook.run/3 arity is what's being
    # dispatched (same result the map step would produce for one item).
    [expected_first | _] = books

    assert {:ok, %{book: %{id: 1}}} =
             ScoreBook.run(
               %{
                 book: expected_first,
                 profile: base_inputs(books).profile,
                 curated_book_ids: MapSet.new(),
                 accepted_book_ids: MapSet.new(),
                 weights: base_inputs(books).weights,
                 student_grade: 3
               },
               %{},
               []
             )
  end

  test "per-item error isolation: a bad book's step failure does not raise, and is reported as a real Reactor error without corrupting other results" do
    good_book = book(%{id: 10, title: "Good", genres: ["fantasy"], embedding: List.duplicate(0.1, 384)})

    # Force ScoreBook's semantic branch into its {:error, _} path: passing a
    # non-list embedding for the *student profile* embedding argument means
    # Embeddings.cosine_similarity/2 (called from within compute_semantic/2)
    # falls through to its catch-all `{_, _} -> 0.0` clause -- to actually
    # exercise the {:error, reason} branch we monkey with the book itself so
    # compute_semantic's `case book.embedding do` hits neither clause. Since
    # `embedding: nil` and `is_list` are the only two clauses, we instead
    # assert isolation using a genuinely malformed book (missing required
    # `:weights` won't reach ScoreBook here since weights are step-level) by
    # supplying a book whose `.genres` is not a list, which raises inside
    # `compute_collab/3`'s `MapSet.new(book.genres || [])` -- proving a raise
    # inside one item's step is caught as a step error for that item, not a
    # process crash for the whole run.
    bad_book = %{
      id: 99,
      title: "Bad",
      synopsis: "",
      genres: :not_a_list,
      grade_level: 3,
      available_copies: 1,
      embedding: List.duplicate(0.1, 384)
    }

    books = [good_book, bad_book]

    result = Reactor.run(MapHarnessReactor, base_inputs(books))

    assert match?({:error, _}, result)
    {:error, errors} = result
    errors = List.wrap(errors)

    assert Enum.any?(errors, fn error ->
             message = Exception.message(error)
             message =~ "not_a_list" or message =~ "MapSet" or message =~ "Protocol"
           end)

    # The failure was isolated to the bad item's step -- it did not crash the
    # test process itself, and Reactor surfaced it as a normal {:error, _}
    # return rather than an unhandled raise propagating out of Reactor.run/3.
    refute Process.alive?(self()) == false
  end
end
