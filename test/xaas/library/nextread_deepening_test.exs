defmodule Xaas.Library.NextReadDeepeningTest do
  @moduledoc """
  Lane W742 — Next Read library-domain atomic-concurrency deepening courts.

  Chicago-style: real Ash actions against the real Postgres test database via
  the Ecto sandbox. No mocks, no interaction assertions — every claim asserts
  real row state re-read from the database.

  Courts:
    (a) borrow/return atomicity under real concurrency: 10 parallel
        `Checkout :borrow` creates against a 5-copy book must yield exactly
        5 successful checkouts and land `available_copies` at exactly 0
        (never negative, never silently overbooked).
    (b) `Xaas.Library.Changes.DecrementBookInventory` fires exactly once per
        successful borrow — inventory is observed stepping down 1:1 with
        each successful create, and a failed borrow (0 copies) leaves
        inventory untouched with no checkout row.
    (c) `RecommendationLog` captures the real 6-factor weight vector and the
        rank output the ranker actually computed (via the real
        `Ranker.rank_recommendations/3` path and its
        `log_recommendations!/4` persistence).
    (d) `Curation.active_for_grade` real scoping: the action's filter is
        `active == true` (grade-band matching happens downstream in the
        ranker), so the court asserts exactly that real shape.
  """

  use Xaas.DataCase, async: false

  require Ash.Query

  alias Xaas.Library.{Book, Checkout, Curation, RecommendationLog, Ranker}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!(attrs \\ %{}), do: Xaas.Generator.create_user!(attrs)

  defp create_book!(attrs \\ %{}), do: Xaas.Generator.create_book!(attrs)

  describe "(a) borrow/return atomicity under real concurrency" do
    test "10 parallel borrows on a 5-copy book: exactly 5 succeed, inventory lands at 0" do
      book = create_book!(%{available_copies: 5, total_copies: 5})
      users = for _ <- 1..10, do: create_user!()

      results =
        users
        |> Task.async_stream(
          fn user ->
            Checkout
            |> Ash.Changeset.for_create(
              :borrow,
              %{book_id: book.id, user_id: user.id, school_id: "willow-creek"},
              authorize?: false
            )
            |> Ash.create(authorize?: false)
          end,
          max_concurrency: 10,
          timeout: 15_000,
          ordered: false
        )
        |> Enum.map(fn {:ok, result} -> result end)

      successes = Enum.filter(results, &match?({:ok, _}, &1))
      failures = Enum.filter(results, &match?({:error, _}, &1))

      assert length(successes) == 5,
             "expected exactly 5 of 10 concurrent borrows to succeed against 5 copies, " <>
               "got #{length(successes)} successes / #{length(failures)} failures: " <>
               inspect(Enum.map(failures, &elem(&1, 0)), limit: 5)

      assert length(failures) == 5,
             "expected the other 5 concurrent borrows to fail (inventory exhausted)"

      reloaded = Ash.get!(Book, book.id, authorize?: false)
      assert reloaded.available_copies == 0, "inventory must land at exactly 0, never negative"

      checkout_rows =
        Checkout |> Ash.read!(authorize?: false) |> Enum.filter(&(&1.book_id == book.id))

      assert length(checkout_rows) == 5,
             "exactly 5 real Checkout rows must exist — no overbooked rows"

      # Every successful checkout is a real borrowed row.
      assert Enum.all?(checkout_rows, &(&1.status == :borrowed))
      assert Enum.uniq(Enum.map(checkout_rows, & &1.user_id)) |> length() == 5
    end

    test "returned copies become borrowable again: 5-way exhaustion then 1 return, 1 new borrow succeeds" do
      book = create_book!(%{available_copies: 1, total_copies: 1})
      user = create_user!()

      {:ok, checkout} =
        Checkout
        |> Ash.Changeset.for_create(
          :borrow,
          %{book_id: book.id, user_id: user.id, school_id: "willow-creek"},
          authorize?: false
        )
        |> Ash.create(authorize?: false)

      assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0

      # A borrow at 0 copies must fail.
      other = create_user!()

      assert {:error, _} =
               Checkout
               |> Ash.Changeset.for_create(
                 :borrow,
                 %{book_id: book.id, user_id: other.id, school_id: "willow-creek"},
                 authorize?: false
               )
               |> Ash.create(authorize?: false)

      # Return increments inventory back to exactly 1 and marks the row returned.
      assert {:ok, returned} =
               checkout
               |> Ash.Changeset.for_update(:return, %{}, authorize?: false)
               |> Ash.update(authorize?: false)

      assert returned.status == :returned
      assert returned.returned_at != nil
      assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1

      # The freed copy is genuinely borrowable again.
      assert {:ok, _} =
               Checkout
               |> Ash.Changeset.for_create(
                 :borrow,
                 %{book_id: book.id, user_id: other.id, school_id: "willow-creek"},
                 authorize?: false
               )
               |> Ash.create(authorize?: false)

      assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0
    end
  end

  describe "(b) DecrementBookInventory fires exactly once per successful borrow" do
    test "inventory steps down 1:1 with each sequential successful borrow" do
      book = create_book!(%{available_copies: 3, total_copies: 3})

      borrow! = fn ->
        user = create_user!()

        Checkout
        |> Ash.Changeset.for_create(
          :borrow,
          %{book_id: book.id, user_id: user.id, school_id: "willow-creek"},
          authorize?: false
        )
        |> Ash.create!(authorize?: false)
      end

      checkout_1 = borrow!.()
      inventory_1 = Ash.get!(Book, book.id, authorize?: false).available_copies

      checkout_2 = borrow!.()
      inventory_2 = Ash.get!(Book, book.id, authorize?: false).available_copies

      checkout_3 = borrow!.()
      inventory_3 = Ash.get!(Book, book.id, authorize?: false).available_copies

      checkouts = [checkout_1, checkout_2, checkout_3]
      inventories = [inventory_1, inventory_2, inventory_3]

      # The 3 sequential successful borrows stepped inventory 3 -> 2 -> 1 -> 0,
      # exactly one decrement per successful create.
      assert inventories == [2, 1, 0]
      assert length(checkouts) == 3

      reloaded = Ash.get!(Book, book.id, authorize?: false)
      assert reloaded.available_copies == 0
      assert reloaded.total_copies == 3, "total_copies is never touched by the decrement"
    end

    test "a failed borrow at zero copies decrements nothing and writes no checkout row" do
      book = create_book!(%{available_copies: 0, total_copies: 1})
      user = create_user!()

      assert {:error, _error} =
               Checkout
               |> Ash.Changeset.for_create(
                 :borrow,
                 %{book_id: book.id, user_id: user.id, school_id: "willow-creek"},
                 authorize?: false
               )
               |> Ash.create(authorize?: false)

      reloaded = Ash.get!(Book, book.id, authorize?: false)
      assert reloaded.available_copies == 0

      checkout_rows =
        Checkout |> Ash.read!(authorize?: false) |> Enum.filter(&(&1.book_id == book.id))

      assert checkout_rows == [],
             "the failed borrow must roll back the whole create — no checkout row"
    end
  end

  describe "(c) RecommendationLog captures the 6-factor weights and rank output" do
    test "default weights are the real 6-factor vector summing to ~1.0" do
      weights = Ranker.weights()

      assert MapSet.new(Map.keys(weights)) ==
               MapSet.new([:collab, :semantic, :grade_fit, :available, :diversity, :curation])

      # The real ontology-sourced vector (0.34/0.26/0.16/0.10/0.06/0.09) sums
      # to 1.01 — assert the normalized ~1.0 envelope, not exact 1.0.
      assert_in_delta Enum.reduce(Map.values(weights), 0.0, &+/2), 1.0, 0.02
    end

    test "rank_recommendations/3 persists a log row whose weights and ranked_items match the real inputs" do
      user = create_user!()

      # A small real catalog: 3 books, one curated (curation factor = 1.0 for it).
      book_a = create_book!(%{title: "Deepening Alpha", grade_level: 5, available_copies: 2})
      book_b = create_book!(%{title: "Deepening Beta", grade_level: 5, available_copies: 0})
      book_c = create_book!(%{title: "Deepening Gamma", grade_level: 5, available_copies: 1})

      Curation
      |> Ash.Changeset.for_create(
        :create,
        %{book_id: book_a.id, curated_by: "librarian-w742", grade_band: "3-5", active: true},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

      weights_before = Ranker.weights()

      assert {:ok, scored} = Ranker.rank_recommendations(user.id, 5, limit: 10)

      # W984ly: the ranker pools the WHOLE shared catalog, so both the
      # returned list and the logged pool size are bounded by the real
      # catalog size, never by the suite's 3 fixtures alone (W984lh idiom).
      candidate_pool = Book |> Ash.Query.select([]) |> Ash.read!(authorize?: false) |> length()
      assert length(scored) == min(10, candidate_pool)

      assert scored == Enum.sort_by(scored, & &1.score, :desc)

      Enum.each(scored, fn entry ->
        assert MapSet.new(Map.keys(entry.factors)) ==
                 MapSet.new([
                   :collab,
                   :semantic,
                   :grade_fit,
                   :available,
                   :diversity,
                   :curation
                 ])

        expected_total =
          weights_before.collab * entry.factors.collab +
            weights_before.semantic * entry.factors.semantic +
            weights_before.grade_fit * entry.factors.grade_fit +
            weights_before.available * entry.factors.available +
            weights_before.diversity * entry.factors.diversity +
            weights_before.curation * entry.factors.curation

        assert_in_delta entry.score, expected_total, 0.0001
      end)

      # The curated, available book carries curation == 1.0 and availability == 1.0.
      curated_entry = Enum.find(scored, &(&1.book.id == book_a.id))
      assert curated_entry.factors.curation == 1.0
      assert curated_entry.factors.available == 1.0

      # The out-of-stock book carries availability == 0.0.
      unavailable_entry = Enum.find(scored, &(&1.book.id == book_b.id))
      assert unavailable_entry.factors.available == 0.0

      # Real persisted log row: exactly one FOR THIS READER (W984ly: scoped —
      # the shared table may carry committed rows from other runs).
      logs =
        RecommendationLog
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read!(authorize?: false)

      assert length(logs) == 1, "exactly one RecommendationLog row for one rank run"

      log = hd(logs)
      assert log.user_id == user.id
      assert log.candidate_pool_size == candidate_pool
      assert log.accepted == false

      # Stored weights equal the weights actually used in the computation.
      # The `:map` attribute round-trips Postgres jsonb, so keys come back as
      # strings — compare on normalized keys.
      stored_weights =
        Map.new(log.weights, fn {k, v} -> {k |> to_string() |> String.to_atom(), v} end)

      assert stored_weights == weights_before

      # Stored ranked_items mirror the produced ranking (book_id/title/score).
      stored = Enum.map(log.ranked_items, fn item -> {item["book_id"], item["title"], item["score"]} end)
      produced = Enum.map(scored, fn %{book: b, score: s} -> {b.id, b.title, s} end)
      assert stored == produced

      # Spot-check the curated book is present in the stored ranking.
      assert Enum.any?(stored, fn {book_id, _title, _score} -> book_id == book_a.id end)
      assert Enum.any?(stored, fn {book_id, _title, _score} -> book_id == book_c.id end)
    end
  end

  describe "(d) Curation.active_for_grade scoping" do
    test "returns only active==true rows; the grade filter is applied downstream in the ranker" do
      book_1 = create_book!()
      book_2 = create_book!()
      book_3 = create_book!()

      active_band = create_curation!(book_1, "3-5", active: true)
      _active_other_band = create_curation!(book_2, "6-8", active: true)
      _inactive = create_curation!(book_3, "3-5", active: false)

      results =
        Curation
        |> Ash.Query.for_read(:active_for_grade, %{grade_level: 4})
        |> Ash.read!(authorize?: false)

      ids = Enum.map(results, & &1.id)

      assert active_band.id in ids, "the active 3-5 curation must be returned"
      refute Enum.any?(results, &(&1.active == false)), "no inactive row may be returned"
      # Real action shape: filter is `active == true` only — the band match
      # happens in Ranker.matches_grade_band?/2, not in this query.
      assert Enum.all?(results, &(&1.active == true))
    end

    test "flipping a curation to active: false removes it from active_for_grade results" do
      book = create_book!()
      curation = create_curation!(book, "6-8", active: true)

      assert {:ok, updated} =
               curation
               |> Ash.Changeset.for_update(:update, %{active: false}, authorize?: false)
               |> Ash.update(authorize?: false)

      assert updated.active == false

      results =
        Curation
        |> Ash.Query.for_read(:active_for_grade, %{grade_level: 7})
        |> Ash.read!(authorize?: false)

      refute Enum.any?(results, &(&1.id == curation.id))
    end

    test "grade_level argument is required" do
      assert_raise Ash.Error.Invalid, ~r/required/, fn ->
        Curation
        |> Ash.Query.for_read(:active_for_grade, %{})
        |> Ash.read!(authorize?: false)
      end
    end
  end

  defp create_curation!(book, band, opts) do
    Curation
    |> Ash.Changeset.for_create(
      :create,
      %{
        book_id: book.id,
        curated_by: "librarian-w742",
        grade_band: band,
        active: Keyword.get(opts, :active, true)
      },
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end
end
