defmodule Xaas.Library.RankerTest do
  @moduledoc """
  Chicago-school test suite for `Xaas.Library.Ranker`, isolating each of the
  6 composite scoring factors (collab, semantic, grade_fit, available,
  diversity, curation) with real seeded Book/Checkout/Curation fixtures and
  real Postgres reads via Ash -- zero mocks. Also covers `exclude_read`,
  `limit`, and the empty-catalog edge case.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Checkout, Config, Curation, Ranker}
  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!(email \\ nil) do
    user_email = email || Faker.Internet.email()

    Ash.Seed.seed!(User, %{
      email: user_email
    })
  end

  defp create_book!(attrs) do
    title = Map.get(attrs, :title, Faker.Commerce.product_name())
    author = Map.get(attrs, :author, Faker.Person.name())
    isbn = Map.get(attrs, :isbn, Faker.Commerce.color() <> "-#{System.unique_integer([:positive])}")
    grade_level = Map.get(attrs, :grade_level, Enum.random(3..8))
    genres = Map.get(attrs, :genres, ["Fiction", "Adventure"])
    synopsis = Map.get(attrs, :synopsis, Faker.Lorem.paragraph(2))
    available_copies = Map.get(attrs, :available_copies, 2)
    total_copies = Map.get(attrs, :total_copies, 2)

    Book
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      author: author,
      isbn: isbn,
      grade_level: grade_level,
      genres: genres,
      synopsis: synopsis,
      available_copies: available_copies,
      total_copies: total_copies
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_checkout!(user, book) do
    Checkout
    |> Ash.Changeset.for_create(:create, %{
      user_id: user.id,
      book_id: book.id,
      school_id: Config.default_school_id(),
      status: :borrowed
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_curation!(book, grade_band, reason) do
    Curation
    |> Ash.Changeset.for_create(:create, %{
      book_id: book.id,
      curated_by: "Librarian Mrs. Hudson",
      grade_band: grade_band,
      reason: reason,
      active: true
    })
    |> Ash.create!(authorize?: false)
  end

  defp factors_for(recommendations, book) do
    rec = Enum.find(recommendations, &(&1.book.id == book.id))
    assert rec != nil, "expected a recommendation for book #{book.title}"
    rec.factors
  end

  describe "collab factor" do
    test "rises when a candidate book shares genres with the reader's checkout history" do
      user = create_user!()

      history_book =
        create_book!(%{title: "History Mystery One", genres: ["Mystery", "Cryptography"], grade_level: 6})

      create_checkout!(user, history_book)

      overlapping_book =
        create_book!(%{title: "Overlapping Genres", genres: ["Mystery", "Cryptography"], grade_level: 6})

      disjoint_book =
        create_book!(%{title: "Disjoint Genres", genres: ["Cooking", "Travel"], grade_level: 6})

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      overlap_factors = factors_for(recs, overlapping_book)
      disjoint_factors = factors_for(recs, disjoint_book)

      assert overlap_factors.collab == 1.0
      assert disjoint_factors.collab == 0.0
      assert overlap_factors.collab > disjoint_factors.collab
    end

    test "defaults collab to 0.5 for a reader with no checkout history" do
      user = create_user!()
      book = create_book!(%{title: "No History Book", genres: ["Fantasy"], grade_level: 6})

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      assert factors_for(recs, book).collab == 0.5
    end
  end

  describe "semantic factor" do
    test "rises with cosine similarity between reader profile embedding and book embedding" do
      user = create_user!()

      history_book =
        create_book!(%{
          title: "Deep Sea Marine Biology",
          synopsis: "Ocean exploration, marine biology, and submarine expeditions in deep trenches.",
          genres: ["Science", "Oceanography"],
          grade_level: 6
        })

      create_checkout!(user, history_book)

      similar_book =
        create_book!(%{
          title: "Ocean Trench Expedition",
          synopsis: "Ocean exploration, marine biology, and submarine expeditions in deep trenches.",
          genres: ["Science", "Oceanography"],
          grade_level: 6
        })

      dissimilar_book =
        create_book!(%{
          title: "Ancient Roman Pottery",
          synopsis: "Ancient roman pottery, architecture, and archaeology excavations of ruins.",
          genres: ["History", "Archaeology"],
          grade_level: 6
        })

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      similar_factors = factors_for(recs, similar_book)
      dissimilar_factors = factors_for(recs, dissimilar_book)

      assert similar_factors.semantic > dissimilar_factors.semantic
    end

    test "computes semantic score on demand from title/synopsis/genres when embedding is nil" do
      user = create_user!()
      book = create_book!(%{title: "Embedding On Demand", genres: ["Mystery"], grade_level: 6})

      # Force a nil stored embedding directly via Ash update, bypassing the
      # test helper's precomputed embedding, to exercise the on-demand
      # embed/1 branch in compute_semantic_score/2. `:embedding` is not in
      # the `:update` action's accept list (it is derived automatically via
      # the vectorize `:after_action` strategy from `:synopsis` -- see
      # lib/xaas/library/book.ex), so this uses force_change_attribute/3 to
      # write it directly, bypassing the accept-list check, rather than
      # passing it as an action param (which Ash now rejects).
      book =
        book
        |> Ash.Changeset.for_update(:update, %{})
        |> Ash.Changeset.force_change_attribute(:embedding, nil)
        |> Ash.update!(authorize?: false)

      assert book.embedding == nil

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)
      factors = factors_for(recs, book)

      assert is_float(factors.semantic)
      assert factors.semantic >= 0.0 and factors.semantic <= 1.0
    end
  end

  describe "grade_fit factor" do
    test "decays as the book's grade level moves further from the student's grade" do
      user = create_user!()

      exact_match = create_book!(%{title: "Exact Grade Match", grade_level: 6, genres: ["Fiction"]})
      near_match = create_book!(%{title: "Near Grade Match", grade_level: 7, genres: ["Fiction"]})
      far_mismatch = create_book!(%{title: "Far Grade Mismatch", grade_level: 11, genres: ["Fiction"]})

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      exact_factors = factors_for(recs, exact_match)
      near_factors = factors_for(recs, near_match)
      far_factors = factors_for(recs, far_mismatch)

      assert exact_factors.grade_fit == 1.0
      assert near_factors.grade_fit < exact_factors.grade_fit
      assert far_factors.grade_fit < near_factors.grade_fit
      assert far_factors.grade_fit <= Config.grade_fit_fallback() or far_factors.grade_fit == 0.35
    end
  end

  describe "available factor" do
    test "is 1.0 when copies are on the shelf and 0.0 when none are available" do
      user = create_user!()

      available_book =
        create_book!(%{title: "On The Shelf", grade_level: 6, genres: ["Fiction"], available_copies: 3})

      unavailable_book =
        create_book!(%{title: "All Checked Out", grade_level: 6, genres: ["Fiction"], available_copies: 0})

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      assert factors_for(recs, available_book).available == 1.0
      assert factors_for(recs, unavailable_book).available == 0.0
    end
  end

  describe "diversity factor" do
    test "is lower for genres the reader has already checked out heavily, higher for unexplored genres" do
      user = create_user!()

      # Build heavy checkout history in "Mystery" so future Mystery books
      # score low diversity, while an unexplored genre scores high.
      for i <- 1..4 do
        heavy_book =
          create_book!(%{title: "Mystery History #{i}", genres: ["Mystery"], grade_level: 6})

        create_checkout!(user, heavy_book)
      end

      heavily_read_genre_book =
        create_book!(%{title: "Another Mystery Title", genres: ["Mystery"], grade_level: 6})

      unexplored_genre_book =
        create_book!(%{title: "Brand New Genre", genres: ["Poetry"], grade_level: 6})

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 20)

      heavy_factors = factors_for(recs, heavily_read_genre_book)
      unexplored_factors = factors_for(recs, unexplored_genre_book)

      assert unexplored_factors.diversity > heavy_factors.diversity
      assert heavy_factors.diversity == 0.0
      assert unexplored_factors.diversity == 1.0
    end

    test "defaults diversity to 0.5 when the candidate book has no genres" do
      user = create_user!()
      book = create_book!(%{title: "Genreless Book", genres: [], grade_level: 6})

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      assert factors_for(recs, book).diversity == 0.5
    end
  end

  describe "curation factor" do
    test "is 1.0 only for books with an active curation matching the student's grade band" do
      user = create_user!()

      curated_book = create_book!(%{title: "Librarian Pick", grade_level: 6, genres: ["Fiction"]})
      create_curation!(curated_book, "6-8", "Great for this grade band")

      out_of_band_book = create_book!(%{title: "Curated Out Of Band", grade_level: 6, genres: ["Fiction"]})
      create_curation!(out_of_band_book, "9-12", "Not this student's band")

      uncurated_book = create_book!(%{title: "No Curation At All", grade_level: 6, genres: ["Fiction"]})

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      assert factors_for(recs, curated_book).curation == 1.0
      assert factors_for(recs, out_of_band_book).curation == 0.0
      assert factors_for(recs, uncurated_book).curation == 0.0
    end

    test "an inactive curation does not contribute a curation boost" do
      user = create_user!()
      book = create_book!(%{title: "Inactive Curation Book", grade_level: 6, genres: ["Fiction"]})

      Curation
      |> Ash.Changeset.for_create(:create, %{
        book_id: book.id,
        curated_by: "Librarian Mrs. Hudson",
        grade_band: "6-8",
        reason: "Was pulled from spotlight",
        active: false
      })
      |> Ash.create!(authorize?: false)

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      assert factors_for(recs, book).curation == 0.0
    end
  end

  describe "exclude_read option" do
    test "excludes already-checked-out books by default" do
      user = create_user!()
      read_book = create_book!(%{title: "Already Read", grade_level: 6, genres: ["Fiction"]})
      create_checkout!(user, read_book)
      unread_book = create_book!(%{title: "Not Yet Read", grade_level: 6, genres: ["Fiction"]})

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      assert Enum.find(recs, &(&1.book.id == read_book.id)) == nil
      assert Enum.find(recs, &(&1.book.id == unread_book.id)) != nil
    end

    test "includes already-checked-out books when exclude_read: false" do
      user = create_user!()
      read_book = create_book!(%{title: "Already Read Included", grade_level: 6, genres: ["Fiction"]})
      create_checkout!(user, read_book)

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, exclude_read: false, limit: 10)

      assert Enum.find(recs, &(&1.book.id == read_book.id)) != nil
    end
  end

  describe "limit option" do
    test "caps the number of returned recommendations to the given limit" do
      user = create_user!()

      for i <- 1..5 do
        create_book!(%{title: "Limit Candidate #{i}", grade_level: 6, genres: ["Fiction"]})
      end

      {:ok, recs_limited} = Ranker.rank_recommendations(user.id, 6, limit: 2)
      {:ok, recs_unlimited} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      assert length(recs_limited) == 2
      assert length(recs_unlimited) >= 5
    end

    test "defaults to a limit of 10 when no limit option is given" do
      user = create_user!()

      for i <- 1..12 do
        create_book!(%{title: "Default Limit Candidate #{i}", grade_level: 6, genres: ["Fiction"]})
      end

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6)

      assert length(recs) == 10
    end
  end

  describe "empty catalog edge case" do
    test "returns an empty recommendation list when there are no candidate books" do
      user = create_user!()

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      assert recs == []
    end

    test "returns an empty list when every catalog book has already been checked out and exclude_read is true" do
      user = create_user!()
      only_book = create_book!(%{title: "Only Book In Catalog", grade_level: 6, genres: ["Fiction"]})
      create_checkout!(user, only_book)

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      assert recs == []
    end
  end
end
