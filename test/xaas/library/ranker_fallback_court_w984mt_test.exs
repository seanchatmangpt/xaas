defmodule Xaas.Library.RankerFallbackCourtW984mtTest do
  @moduledoc """
  W984mt — closes the two W984me findings:

  (a) `Xaas.Library.Ranker`'s ~160-line procedural fallback
  (`rank_recommendations_procedural/2` and its private factor helpers) was
  dead under every court — every procedural-only mutant survived. This
  court forces the fallback arm for real: a non-integer `student_grade`
  (e.g. "six") fails the real Ash argument cast on
  `Curation.active_for_grade`'s `grade_level` (:integer, allow_nil?: false)
  inside `RecommendationPipelineReactor`'s `:get_active_curations` read
  step, so `Reactor.run/3` returns `{:ok,_}`→`{:error, _}` and
  `rank_recommendations/3` executes `rank_recommendations_procedural/2` —
  no mocks, the real Ash validation failure branches the code. The court
  pins the real procedural branches W984me flagged: factor weighting, sort
  order, curation boost, acceptance boost, tie scores, exclude_read.

  (b) `expected_ranking!/2` in the live deepening court was a shared-oracle
  tautology (ranker asserted against itself). The "independent hand-computed
  oracle" describe below asserts hand-derived expected rankings — small real
  twin catalogs where every factor is held identical except the one under
  test, so the expected order is derivable by hand from the documented
  factor semantics and `Xaas.Library.Config.weights/1` — independent of any
  Ranker code.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.{Book, Checkout, Config, Curation, Ranker, RecommendationLog}
  require Ash.Query

  @fallback_grade "six"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!, do: Xaas.Generator.create_user!()
  defp create_book!(attrs), do: Xaas.Generator.create_book!(attrs)

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

  defp create_curation!(book, band) do
    Curation
    |> Ash.Changeset.for_create(:create, %{
      book_id: book.id,
      curated_by: "Librarian Mrs. Hudson",
      grade_band: band,
      reason: "court fixture",
      active: true
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_rec_log!(user, book, accepted) do
    RecommendationLog
    |> Ash.Changeset.for_create(:create, %{
      user_id: user.id,
      candidate_pool_size: 1,
      weights: Config.weights(),
      ranked_items: [%{"book_id" => book.id, "title" => book.title, "score" => 1.0}],
      accepted: accepted
    })
    |> Ash.create!(authorize?: false)
  end

  defp factors_for(recs, book) do
    rec = Enum.find(recs, &(&1.book.id == book.id))
    assert rec != nil, "expected a recommendation for book #{book.title}"
    rec.factors
  end

  # The test database carries pre-existing catalog rows outside the sandbox
  # transaction, so every ordering assertion is scoped to the fixture subset:
  # the hand-computed expected order must hold for the designed books, wherever
  # unrelated catalog rows land.
  defp assert_ranking(recs, expected_ids) do
    assert Enum.map(Enum.filter(recs, &(&1.book.id in expected_ids)), & &1.book.id) ==
             expected_ids
  end

  defp top_of(recs, expected_ids) do
    recs |> Enum.filter(&(&1.book.id in expected_ids)) |> hd()
  end

  @doc """
  Forces the real fallback arm: a non-integer grade fails the reactor's Ash
  cast, so the returned ranking was produced by
  `rank_recommendations_procedural/2`.
  """
  defp fallback_rank!(user, opts \\ []) do
    opts = Keyword.put_new(opts, :limit, 200)
    assert {:ok, recs} = Ranker.rank_recommendations(user.id, @fallback_grade, opts)
    assert is_list(recs)
    recs
  end

  # Twins share identical embedding text (title is the only differing token —
  # same synopsis/genres) so the semantic factor is held at parity; the
  # designed factor under test is the sole ordering driver.
  defp twin_book_attrs(title, over \\ %{}) do
    Map.merge(
      %{
        title: title,
        synopsis: "Identical twin fixture text for deterministic factor parity.",
        genres: ["Mystery"],
        grade_level: 6
      },
      over
    )
  end

  describe "procedural fallback arm (finding a)" do
    test "integer grade runs the reactor; non-integer grade runs the fallback (differential gate)" do
      user = create_user!()
      book = create_book!(twin_book_attrs("Gate Twin"))
      create_curation!(book, "all")

      {:ok, reactor_recs} = Ranker.rank_recommendations(user.id, 6, limit: 200)
      assert factors_for(reactor_recs, book).curation == 1.0

      fallback_recs = fallback_rank!(user)
      assert factors_for(fallback_recs, book).curation == 1.0
      assert top_of(fallback_recs, [book.id]).factors.curation == 1.0
    end

    test "curation boost is applied in the fallback (W984me M1 procedural kill)" do
      user = create_user!()
      curated = create_book!(twin_book_attrs("Curation Twin A"))
      plain = create_book!(twin_book_attrs("Curation Twin B"))
      create_curation!(curated, "all")

      recs = fallback_rank!(user)
      assert_ranking(recs, [curated.id, plain.id])
      assert factors_for(recs, curated).curation == 1.0
      assert factors_for(recs, plain).curation == 0.0
    end

    test "fallback ordering is non-increasing across designed distinct scores (sort court)" do
      user = create_user!()
      shared = "Rank court twin shared synopsis text for semantic parity."

      b1 = create_book!(twin_book_attrs("Rank Court Twin One", %{synopsis: shared}))
      b2 = create_book!(twin_book_attrs("Rank Court Twin Two", %{synopsis: shared}))
      b3 = create_book!(twin_book_attrs("Rank Court Outlier", %{genres: ["Cooking"]}))

      create_curation!(b1, "all")
      create_checkout!(user, create_book!(twin_book_attrs("History Book")))

      # b1: collab 1.0 + curation 1.0; b2: collab 1.0; b3: collab 0.0.
      # collab swing (w=0.34) dominates the max possible semantic swing
      # (w=0.26), so expected order [b1, b2, b3] is hand-derivable.
      recs = fallback_rank!(user)
      assert_ranking(recs, [b1.id, b2.id, b3.id])

      scores = Enum.map(recs, & &1.score)
      assert scores == Enum.sort(scores, :desc)
      subset_scores =
        recs |> Enum.filter(&(&1.book.id in [b1.id, b2.id, b3.id])) |> Enum.map(& &1.score)

      assert Enum.dedup(subset_scores) == subset_scores, "designed scores must be distinct"

      assert factors_for(recs, b1).collab == 1.0
      assert factors_for(recs, b2).collab == 1.0
      assert factors_for(recs, b3).collab == 0.0
      assert factors_for(recs, b1).curation == 1.0
      assert factors_for(recs, b3).curation == 0.0
    end

    test "acceptance boost: accepted prior recommendation lifts collab to 0.75 (M3-analog kill)" do
      user = create_user!()
      accepted_book = create_book!(twin_book_attrs("Acceptance Twin A"))
      plain = create_book!(twin_book_attrs("Acceptance Twin B"))
      create_rec_log!(user, accepted_book, true)
      create_rec_log!(user, plain, false)

      recs = fallback_rank!(user)
      assert_ranking(recs, [accepted_book.id, plain.id])
      assert factors_for(recs, accepted_book).collab == 0.75
      assert factors_for(recs, plain).collab == 0.5
    end

    test "factor weighting: curation weight magnitude and sign flip the ranking" do
      user = create_user!()
      curated = create_book!(twin_book_attrs("Weight Twin A"))
      plain = create_book!(twin_book_attrs("Weight Twin B"))
      create_curation!(curated, "all")

      # Magnitude: w.curation = 1.0 overwhelms any parity factor -> curated first.
      recs_pos = fallback_rank!(user, weights: %{curation: 1.0})
      assert_ranking(recs_pos, [curated.id, plain.id])
      assert top_of(recs_pos, [curated.id, plain.id]).factors.curation == 1.0

      # Sign: w.curation = -1.0 -> the curated book ranks BELOW its plain
      # twin — proves the weight multiplies the factor, not membership.
      recs_neg = fallback_rank!(user, weights: %{curation: -1.0})
      assert_ranking(recs_neg, [plain.id, curated.id])
      assert top_of(recs_neg, [plain.id, curated.id]).factors.curation == 0.0
      assert Enum.find(recs_neg, &(&1.book.id == curated.id)).factors.curation == 1.0
    end

    test "exclude_read drops checked-out books in the fallback; opt-in restores them" do
      user = create_user!()
      read_book = create_book!(twin_book_attrs("Read Twin"))
      fresh = create_book!(twin_book_attrs("Fresh Twin"))
      create_checkout!(user, read_book)

      recs = fallback_rank!(user)
      refute Enum.find(recs, &(&1.book.id == read_book.id))

      recs_all = fallback_rank!(user, exclude_read: false)
      assert Enum.find(recs_all, &(&1.book.id == read_book.id))
      assert Enum.find(recs_all, &(&1.book.id == fresh.id))
    end

    test "grade_fit and diversity pins in the fallback" do
      user = create_user!()
      _near = create_book!(twin_book_attrs("Pins Twin Near"))
      far = create_book!(twin_book_attrs("Pins Twin Far", %{grade_level: 12}))
      cook = create_book!(twin_book_attrs("Pins Twin Cooking", %{genres: ["Cooking"]}))
      create_checkout!(user, create_book!(twin_book_attrs("Pins History", %{genres: ["Mystery"]})))
      create_checkout!(user, create_book!(twin_book_attrs("Pins History 2", %{genres: ["Mystery"]})))

      recs = fallback_rank!(user)

      # grade_fit: delta 6 exceeds all documented thresholds -> fallback 0.10.
      assert factors_for(recs, far).grade_fit == 0.10

      # diversity: past = 2x Mystery (total 2) -> Mystery book: 1.0 - min(1, 2/2) = 0.0;
      # Cooking book: 1.0 - 0 = 1.0.
      mystery_rec = Enum.find(recs, &(&1.book.genres == ["Mystery"]))
      assert mystery_rec.factors.diversity == 0.0
      assert factors_for(recs, cook).diversity == 1.0
    end

    test "tie scores: identical twins produce exactly equal scores and both appear" do
      user = create_user!()
      t1 = create_book!(twin_book_attrs("Tie Twin"))
      t2 = create_book!(twin_book_attrs("Tie Twin"))
      create_curation!(t1, "all")
      create_curation!(t2, "all")

      recs = fallback_rank!(user)
      twin_recs = Enum.filter(recs, &(&1.book.id in [t1.id, t2.id]))
      assert Enum.map(twin_recs, & &1.book.id) in [[t1.id, t2.id], [t2.id, t1.id]]
      scores = Enum.map(twin_recs, & &1.score)
      assert Enum.dedup(scores) == [hd(scores)]
      assert hd(twin_recs).score == List.last(twin_recs).score
    end
  end

  describe "independent hand-computed oracle (finding b) — reactor path" do
    test "twin pair differing only by grade level: nearer grade ranks first" do
      user = create_user!()
      near = create_book!(twin_book_attrs("Oracle Twin Near"))
      far = create_book!(twin_book_attrs("Oracle Twin Far", %{grade_level: 12}))

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 200)

      # Hand computation: identical synopsis+genres text (semantic parity);
      # collab 0.5 each (no history); diversity 0.8 each (empty past);
      # available 1.0 each; curation 0.0 each. Only grade_fit differs:
      # reactor's linear decay max(0, 1 - delta*0.3): delta 0 -> 1.0 vs
      # delta 6 -> max(0, -0.8) = 0.0; swing = 0.16 * 1.0 = 0.16.
      assert_ranking(recs, [near.id, far.id])
      assert factors_for(recs, near).grade_fit == 1.0
      assert factors_for(recs, far).grade_fit == 0.0
    end

    test "twin pair differing only by active curation: curated ranks first" do
      user = create_user!()
      curated = create_book!(twin_book_attrs("Oracle Twin Curated"))
      plain = create_book!(twin_book_attrs("Oracle Twin Plain"))
      create_curation!(curated, "all")

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 200)

      # Hand computation: only curation differs (1.0 vs 0.0); swing
      # = w.curation * 1.0 = 0.09; every other factor identical.
      assert_ranking(recs, [curated.id, plain.id])
      assert factors_for(recs, curated).curation == 1.0
      assert factors_for(recs, plain).curation == 0.0
    end

    test "twin pair differing only by prior acceptance: accepted ranks first" do
      user = create_user!()
      acc = create_book!(twin_book_attrs("Oracle Twin Accepted"))
      plain = create_book!(twin_book_attrs("Oracle Twin Plain"))
      create_rec_log!(user, acc, true)

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 200)

      # Hand computation: only collab differs — accepted book
      # min(1.0, 0.5 + 0.25) = 0.75 vs 0.5; swing = 0.34 * 0.25 = 0.085.
      assert_ranking(recs, [acc.id, plain.id])
      assert factors_for(recs, acc).collab == 0.75
      assert factors_for(recs, plain).collab == 0.5
    end

    test "twin pair differing only by availability: available ranks first" do
      user = create_user!()
      avail = create_book!(twin_book_attrs("Oracle Twin Available"))
      out = create_book!(twin_book_attrs("Oracle Twin Out", %{available_copies: 0}))

      {:ok, recs} = Ranker.rank_recommendations(user.id, 6, limit: 200)

      # Hand computation: only `available` differs (1.0 vs 0.0);
      # swing = w.available * 1.0 = 0.10; identical text otherwise.
      assert_ranking(recs, [avail.id, out.id])
      assert factors_for(recs, avail).available == 1.0
      assert factors_for(recs, out).available == 0.0
    end
  end
end
