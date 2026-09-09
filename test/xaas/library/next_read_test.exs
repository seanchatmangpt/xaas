defmodule Xaas.Library.NextReadTest do
  @moduledoc """
  Chicago-school unit and integration test suite for Xaas.Library domain,
  resources (Book, Checkout, Curation), Embeddings, Config, and the 6-factor composite Ranker.

  Executes against real Postgres database via Sandbox, uses Faker for realistic inputs,
  tests state transitions, ranking scores, and PubSub broadcasts. Zero test doubles/mocks.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Library.{Book, Checkout, Config, Curation, Embeddings, Ranker}
  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!(email \\ nil) do
    if email, do: Xaas.Factory.create_user!(%{email: email}), else: Xaas.Factory.create_user!()
  end

  defp create_book!(attrs), do: Xaas.Factory.create_book!(attrs)

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

  describe "Xaas.Library Resources (Book, Checkout, Curation)" do
    test "creates, reads, and updates library books with real Postgres persistence" do
      book =
        create_book!(%{
          title: "The Salt Road Cipher",
          grade_level: 6,
          genres: ["Mystery", "Cipher"]
        })

      assert book.id != nil
      assert book.title == "The Salt Road Cipher"
      assert Decimal.to_integer(book.grade_level) == 6
      assert book.genres == ["Mystery", "Cipher"]

      # Real fix: Book.embedding is a pgvector-backed Ash.Vector (via the
      # `vectorize` DSL), not a plain list -- Ecto/AshPostgres loads it back
      # as a real %Ash.Vector{} struct. Same pattern already fixed in
      # ranker.ex/compute_semantic_score and score_book.ex/compute_semantic.
      assert %Ash.Vector{} = book.embedding
      assert length(Ash.Vector.to_list(book.embedding)) == 384

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

  describe "Dynamic Configuration & 6-Factor Next Read Composite Ranker" do
    test "correctly scores and ranks candidate books based on dynamic 6 composite factors" do
      user = create_user!("maya.r@school.district.edu")

      prior_book1 =
        create_book!(%{
          title: "The Codebreaker's Secret",
          grade_level: 6,
          genres: ["Mystery", "Cryptography"],
          synopsis: "Solving complex cryptographic puzzles and historical codes."
        })

      prior_book2 =
        create_book!(%{
          title: "Ocean Exploration Handbook",
          grade_level: 6,
          genres: ["Science", "Oceanography"],
          synopsis: "Deep sea exploration, marine biology, and submarine expeditions."
        })

      create_checkout!(user, prior_book1)
      create_checkout!(user, prior_book2)

      top_book =
        create_book!(%{
          title: "The Salt Road Cipher",
          grade_level: 6,
          genres: ["Mystery", "Cryptography"],
          synopsis: "Ancient cipher codes hidden along old desert trade routes.",
          available_copies: 2
        })

      create_curation!(top_book, "6-8", "Librarian recommended for mystery lovers.")

      mid_book =
        create_book!(%{
          title: "Bloom of the Deep",
          grade_level: 6,
          genres: ["Science", "Nature"],
          synopsis: "Bioluminescence and glowing organisms in the ocean trenches.",
          available_copies: 1
        })

      low_book =
        create_book!(%{
          title: "Advanced Quantum Mechanics XI",
          grade_level: 11,
          genres: ["Physics", "Mathematics"],
          synopsis: "Rigorous quantum mechanics formalism for advanced students.",
          available_copies: 0
        })

      {:ok, recommendations} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      assert length(recommendations) >= 3

      rec_top = Enum.find(recommendations, &(&1.book.id == top_book.id))
      rec_mid = Enum.find(recommendations, &(&1.book.id == mid_book.id))
      rec_low = Enum.find(recommendations, &(&1.book.id == low_book.id))

      assert rec_top != nil
      assert rec_mid != nil
      assert rec_low != nil

      assert rec_top.factors.grade_fit == 1.0
      assert rec_top.factors.available == 1.0
      assert rec_top.factors.curation == 1.0

      assert rec_low.factors.available == 0.0
      assert rec_low.factors.grade_fit <= 0.20

      assert rec_top.score > rec_mid.score
      assert rec_mid.score > rec_low.score

      weights = Config.weights()
      assert weights.collab == 0.34
      assert weights.semantic == 0.26
      assert weights.grade_fit == 0.16
      assert weights.available == 0.10
      assert weights.diversity == 0.06
      assert weights.curation == 0.09
      assert Float.round(Enum.sum(Map.values(weights)), 2) == 1.01
    end

    test "allows runtime weight overrides without altering codebase" do
      user = create_user!()
      book_a = create_book!(%{title: "Curation Preferred", grade_level: 6, available_copies: 1})
      _book_b = create_book!(%{title: "Standard Choice", grade_level: 6, available_copies: 1})
      create_curation!(book_a, "6-8", "Essential Pick")

      custom_weights = %{
        collab: 0.10,
        semantic: 0.10,
        grade_fit: 0.10,
        available: 0.10,
        diversity: 0.10,
        curation: 0.50
      }

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, weights: custom_weights, limit: 2)
      assert hd(recs).book.id == book_a.id
    end

    test "generates grounded rationale explanations and breakdown parts for recommendations" do
      user = create_user!()
      book = create_book!(%{title: "The Wildwater Signal", grade_level: 6})
      create_checkout!(user, book)

      candidate =
        create_book!(%{title: "The Salt Road Cipher", grade_level: 5.4, available_copies: 3})

      _curation = create_curation!(candidate, "6-8", "Librarian pin")

      {:ok, [rec | _]} = Ranker.rank_recommendations(user.id, 6, limit: 1)

      explanation =
        Ranker.explain_recommendation(rec.book, rec.factors, [
          hd(Checkout |> Ash.read!(authorize?: false))
        ])

      assert String.contains?(explanation.why, "Because you finished")
      assert Enum.any?(explanation.parts, &String.starts_with?(&1, "collaborative"))
      assert Enum.any?(explanation.parts, &String.starts_with?(&1, "semantic"))
      assert Enum.any?(explanation.parts, &String.starts_with?(&1, "grade fit"))
    end

    test "rank_recommendations/3 writes a RecommendationLog row for later feedback/analytics" do
      user = create_user!()
      _book_a = create_book!(%{title: "Logged Pick A", grade_level: 6, available_copies: 1})
      _book_b = create_book!(%{title: "Logged Pick B", grade_level: 6, available_copies: 1})

      before_count =
        Xaas.Library.RecommendationLog
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read!(authorize?: false)
        |> length()

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 2)

      logs =
        Xaas.Library.RecommendationLog
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read!(authorize?: false)

      assert length(logs) == before_count + 1

      log = Enum.max_by(logs, & &1.inserted_at)

      assert log.candidate_pool_size >= length(recs)
      assert log.weights["collab"] == Config.weights().collab
      assert log.accepted == false

      logged_ids =
        log.ranked_items
        |> Enum.map(&(Map.get(&1, "book_id") || Map.get(&1, :book_id)))
        |> MapSet.new()

      recommended_ids = recs |> Enum.map(& &1.book.id) |> MapSet.new()
      assert MapSet.equal?(logged_ids, recommended_ids)
    end

    test "collab_score is boosted by a real prior accepted RecommendationLog for the same book" do
      user = create_user!()

      candidate =
        create_book!(%{
          title: "Previously Accepted Recommendation",
          grade_level: 6,
          genres: ["Fantasy"],
          available_copies: 1
        })

      other =
        create_book!(%{
          title: "Never Recommended Before",
          grade_level: 6,
          genres: ["Fantasy"],
          available_copies: 1
        })

      # Real prior recommendation log, marked accepted, referencing `candidate`'s book_id --
      # exercises the actual data model (RecommendationLog.ranked_items + accepted) rather
      # than a fabricated/mocked signal.
      Xaas.Library.RecommendationLog
      |> Ash.Changeset.for_create(:create, %{
        user_id: user.id,
        candidate_pool_size: 5,
        weights: Config.weights(),
        ranked_items: [%{book_id: candidate.id, title: candidate.title, score: 0.9}],
        accepted: true
      })
      |> Ash.create!(authorize?: false)

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 10)

      rec_candidate = Enum.find(recs, &(&1.book.id == candidate.id))
      rec_other = Enum.find(recs, &(&1.book.id == other.id))

      assert rec_candidate != nil
      assert rec_other != nil

      # Both books start from the same no-checkout-history base collab score (0.5); the
      # previously-accepted book must score strictly higher via the real acceptance-signal
      # query against RecommendationLog.
      assert rec_candidate.factors.collab > rec_other.factors.collab
      assert_in_delta rec_candidate.factors.collab, 0.75, 1.0e-6
      assert_in_delta rec_other.factors.collab, 0.5, 1.0e-6
    end

    test "manages hold requests and queue positions on unavailable titles" do
      user = create_user!()
      book = create_book!(%{title: "Nine Doors to Nowhere", available_copies: 0})

      hold =
        Xaas.Library.HoldRequest
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          book_id: book.id,
          position: 2,
          status: :active
        })
        |> Ash.create!(authorize?: false)

      assert hold.id != nil
      assert hold.position == 2
      assert hold.status == :active
    end

    test "persists recommendation audit logs with 6-factor weight snapshot" do
      user = create_user!()

      log =
        Xaas.Library.RecommendationLog
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          candidate_pool_size: 41,
          weights: Config.weights(),
          ranked_items: [%{rank: 1, title: "The Salt Road Cipher", score: 0.92}],
          accepted: false
        })
        |> Ash.create!(authorize?: false)

      assert log.id != nil
      assert log.candidate_pool_size == 41
      assert log.weights["collab"] == 0.34
    end

    test "loads Ash calculations :is_available and :has_multiple_copies on Book" do
      book_single = create_book!(%{title: "Single Copy", available_copies: 1})
      book_multiple = create_book!(%{title: "Multi Copy", available_copies: 3})
      book_none = create_book!(%{title: "Zero Copy", available_copies: 0})

      loaded_single =
        Ash.get!(Book, book_single.id,
          load: [:is_available, :has_multiple_copies],
          authorize?: false
        )

      loaded_multi =
        Ash.get!(Book, book_multiple.id,
          load: [:is_available, :has_multiple_copies],
          authorize?: false
        )

      loaded_none =
        Ash.get!(Book, book_none.id,
          load: [:is_available, :has_multiple_copies],
          authorize?: false
        )

      assert loaded_single.is_available == true
      assert loaded_single.has_multiple_copies == false

      assert loaded_multi.is_available == true
      assert loaded_multi.has_multiple_copies == true

      assert loaded_none.is_available == false
      assert loaded_none.has_multiple_copies == false
    end

    test "ask_catalog/2 performs semantic search over catalog books and formats admitted answers" do
      _book1 =
        create_book!(%{
          title: "The Quiet Satellite",
          grade_level: 5.2,
          synopsis: "An orbiting telescope detects mysterious space communications.",
          formats: ["Audiobook", "Large Print"],
          available_copies: 4
        })

      _book2 =
        create_book!(%{
          title: "Bloom of the Deep",
          grade_level: 6.1,
          synopsis: "Deep ocean underwater science fiction exploration.",
          formats: ["Large Print"],
          available_copies: 2
        })

      _book3 =
        create_book!(%{
          title: "Signal from the Ninth Floor",
          grade_level: 5.6,
          synopsis: "Students receive signals from an abandoned laboratory.",
          formats: ["Audiobook"],
          available_copies: 1
        })

      result = Ranker.ask_catalog("science fiction signal space", limit: 3)

      assert is_binary(result.summary)
      assert length(result.answers) <= 3
      assert result.candidates_admitted >= 1
      assert Enum.member?(result.telemetry, "Catalog.search_semantic")

      first_answer = hd(result.answers)
      assert is_binary(first_answer.title)
      assert is_binary(first_answer.meta)
    end

    test "broadcasts PubSub notifications on student-scoped circulation channel" do
      user = create_user!()
      book = create_book!(%{title: "PubSub Book", available_copies: 2})

      XaasWeb.Endpoint.subscribe("circulation:student:#{user.id}")

      {:ok, checkout} =
        Checkout
        |> Ash.Changeset.for_create(:borrow, %{
          book_id: book.id,
          user_id: user.id,
          school_id: "willow-creek"
        })
        |> Ash.create(authorize?: false)

      assert_receive %Phoenix.Socket.Broadcast{
        topic: topic,
        event: "borrow",
        payload: %Ash.Notifier.Notification{data: received_checkout}
      }

      assert topic == "circulation:student:#{user.id}"
      assert received_checkout.id == checkout.id
    end
  end
end
