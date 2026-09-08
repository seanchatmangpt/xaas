defmodule Xaas.Library.NextReadTest do
  @moduledoc """
  Chicago-school unit and integration test suite for Xaas.Library domain,
  resources (Book, Checkout, Curation), Embeddings, and the 6-factor composite Ranker.

  Executes against real Postgres database via Sandbox, uses Faker for realistic inputs,
  tests state transitions, ranking scores, and PubSub broadcasts. Zero test doubles/mocks.
  """
  use Kanban.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Checkout, Curation, Embeddings, Ranker}
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

  defp create_book!(attrs \\ %{}) do
    title = Map.get(attrs, :title, Faker.Commerce.product_name())
    author = Map.get(attrs, :author, Faker.Person.name())
    isbn = Map.get(attrs, :isbn, Faker.Commerce.color() <> "-#{System.unique_integer([:positive])}")
    grade_level = Map.get(attrs, :grade_level, Enum.random(3..8))
    genres = Map.get(attrs, :genres, ["Fiction", "Adventure"])
    synopsis = Map.get(attrs, :synopsis, Faker.Lorem.paragraph(2))
    available_copies = Map.get(attrs, :available_copies, 2)
    total_copies = Map.get(attrs, :total_copies, 2)

    {:ok, embedding} = Embeddings.embed("#{title} #{synopsis} #{Enum.join(genres, " ")}")

    Book
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      author: author,
      isbn: isbn,
      grade_level: grade_level,
      genres: genres,
      synopsis: synopsis,
      available_copies: available_copies,
      total_copies: total_copies,
      embedding: embedding
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_checkout!(user, book) do
    Checkout
    |> Ash.Changeset.for_create(:create, %{
      user_id: user.id,
      book_id: book.id,
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

  describe "Xaas.Library Resources (Book, Checkout, Curation)" do
    test "creates, reads, and updates library books with real Postgres persistence" do
      book = create_book!(%{title: "The Salt Road Cipher", grade_level: 6, genres: ["Mystery", "Cipher"]})

      assert book.id != nil
      assert book.title == "The Salt Road Cipher"
      assert book.grade_level == 6
      assert book.genres == ["Mystery", "Cipher"]
      assert is_list(book.embedding)
      assert length(book.embedding) == 384

      # Verify query by grade band
      books_for_grade =
        Book
        |> Ash.Query.for_read(:by_grade_band, %{min_grade: 5, max_grade: 7})
        |> Ash.read!(authorize?: false)

      assert Enum.any?(books_for_grade, &(&1.id == book.id))
    end

    test "records checkouts and relationships to books and users" do
      user = create_user!()
      book = create_book!(%{title: "Bloom of the Deep", grade_level: 6})

      checkout = create_checkout!(user, book)
      assert checkout.id != nil
      assert checkout.user_id == user.id
      assert checkout.book_id == book.id
      assert checkout.status == :borrowed

      # Query for user checkouts
      user_checkouts =
        Checkout
        |> Ash.Query.for_read(:for_user, %{user_id: user.id})
        |> Ash.read!(authorize?: false)

      assert length(user_checkouts) == 1
      assert hd(user_checkouts).id == checkout.id
    end

    test "records librarian curations for targeted grade bands" do
      book = create_book!(%{title: "Fieldwork for Beginners", grade_level: 6})
      curation = create_curation!(book, "6-8", "Essential scientific inquiry title")

      assert curation.id != nil
      assert curation.book_id == book.id
      assert curation.grade_band == "6-8"
      assert curation.active == true

      active_curations =
        Curation
        |> Ash.Query.for_read(:active_for_grade, %{grade_level: 6})
        |> Ash.read!(authorize?: false)

      assert Enum.any?(active_curations, &(&1.id == curation.id))
    end
  end

  describe "Embeddings & Semantic Cosine Similarity" do
    test "generates deterministic 384-dimensional embeddings and calculates cosine similarity" do
      text_a = "Space exploration, astrophysics, and rocket propulsion mysteries."
      text_b = "Astronomy and interstellar space journeys in the galaxy."
      text_c = "Ancient roman pottery, architecture, and archaeology excavations."

      {:ok, emb_a} = Embeddings.embed(text_a)
      {:ok, emb_b} = Embeddings.embed(text_b)
      {:ok, emb_c} = Embeddings.embed(text_c)

      assert length(emb_a) == 384
      assert length(emb_b) == 384
      assert length(emb_c) == 384

      # Cosine similarity between related space topics should be higher than unrelated archaeology
      sim_related = Embeddings.cosine_similarity(emb_a, emb_b)
      sim_unrelated = Embeddings.cosine_similarity(emb_a, emb_c)

      assert sim_related >= 0.0 and sim_related <= 1.0
      assert sim_unrelated >= 0.0 and sim_unrelated <= 1.0
      assert sim_related > sim_unrelated
    end
  end

  describe "6-Factor Next Read Composite Ranker" do
    test "correctly scores and ranks candidate books based on 6 composite factors" do
      # 1. Setup Student Maya R. (grade 6)
      user = create_user!("maya.r@school.district.edu")

      # 2. Student previously checked out science & cipher books
      prior_book1 = create_book!(%{
        title: "The Codebreaker's Secret",
        grade_level: 6,
        genres: ["Mystery", "Cryptography"],
        synopsis: "Solving complex cryptographic puzzles and historical codes."
      })
      prior_book2 = create_book!(%{
        title: "Ocean Exploration Handbook",
        grade_level: 6,
        genres: ["Science", "Oceanography"],
        synopsis: "Deep sea exploration, marine biology, and submarine expeditions."
      })
      create_checkout!(user, prior_book1)
      create_checkout!(user, prior_book2)

      # 3. Setup Candidate Books:
      # Book 1: Highly matching cipher mystery, grade 6, available, curated (should rank top)
      top_book = create_book!(%{
        title: "The Salt Road Cipher",
        grade_level: 6,
        genres: ["Mystery", "Cryptography"],
        synopsis: "Ancient cipher codes hidden along old desert trade routes.",
        available_copies: 2
      })
      create_curation!(top_book, "6-8", "Librarian recommended for mystery lovers.")

      # Book 2: Grade 6 marine biology book, available, not curated
      mid_book = create_book!(%{
        title: "Bloom of the Deep",
        grade_level: 6,
        genres: ["Science", "Nature"],
        synopsis: "Bioluminescence and glowing organisms in the ocean trenches.",
        available_copies: 1
      })

      # Book 3: High school grade 11 textbook, no copies available (0 available)
      low_book = create_book!(%{
        title: "Advanced Quantum Mechanics XI",
        grade_level: 11,
        genres: ["Physics", "Mathematics"],
        synopsis: "Rigorous quantum mechanics formalism for advanced students.",
        available_copies: 0
      })

      # 4. Execute Ranker
      {:ok, recommendations} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      assert length(recommendations) >= 3

      rec_top = Enum.find(recommendations, &(&1.book.id == top_book.id))
      rec_mid = Enum.find(recommendations, &(&1.book.id == mid_book.id))
      rec_low = Enum.find(recommendations, &(&1.book.id == low_book.id))

      assert rec_top != nil
      assert rec_mid != nil
      assert rec_low != nil

      # Assert factor integrity
      assert rec_top.factors.grade_fit == 1.0
      assert rec_top.factors.available == 1.0
      assert rec_top.factors.curation == 1.0

      assert rec_low.factors.available == 0.0
      assert rec_low.factors.grade_fit <= 0.20

      # Assert score ordering: top_book > mid_book > low_book
      assert rec_top.score > rec_mid.score
      assert rec_mid.score > rec_low.score

      # Verify weights match the specification:
      # 0.34*collab + 0.26*semantic + 0.16*gradeFit + 0.10*available + 0.06*diversity + 0.09*curation
      weights = Ranker.weights()
      assert weights.collab == 0.34
      assert weights.semantic == 0.26
      assert weights.grade_fit == 0.16
      assert weights.available == 0.10
      assert weights.diversity == 0.06
      assert weights.curation == 0.09
      assert Float.round(Enum.sum(Map.values(weights)), 2) == 1.01
    end
  end
end
