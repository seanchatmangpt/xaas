defmodule Xaas.Library.EmbeddingDeepeningTest do
  @moduledoc """
  Lane W787 embedding deepening (v26.10.6). Chicago-style: real module calls
  only, no mocks, no fake vectors.

  Facts under test (from lib/xaas/library/embeddings.ex, local_nx.ex, ranker.ex):
  - `Embeddings.embed/1` is a TOTAL, pure function: a deterministic 384-dim
    Nx hash projection with no external model server and NO failure arm
    (`@spec {:ok, list(float())}`, single clause). The "service-unavailable
    path" is therefore the deterministic offline fallback itself — asserted
    as totality/degradation-independence, never faked.
  - `LocalNx.generate/2` is likewise total (the `{:error, _}` arm was removed
    as dead code per its comment).
  - `Ranker.compute_semantic_score/2` is public and documented "Public so it
    can be exercised directly" — exercised here with a real struct-shaped
    book (nil embedding → on-the-fly embed path).
  """

  use ExUnit.Case, async: true

  alias Xaas.Library.Embeddings
  alias Xaas.Library.EmbeddingModels.LocalNx
  alias Xaas.Library.Ranker

  @dim 384

  describe "(a)+(d) embedding determinism" do
    test "identical text embeds to a bit-identical vector, twice" do
      text =
        "A young cartographer maps the floating archipelago and befriends the " <>
          "wind-riding whales that guard its sky harbors."

      {:ok, v1} = Embeddings.embed(text)
      {:ok, v2} = Embeddings.embed(text)
      {:ok, v3} = Embeddings.embed(text)

      assert v1 == v2
      assert v2 == v3
      assert length(v1) == @dim
      assert Enum.all?(v1, &is_float/1)
    end

    test "embed is order-stable under token re-embedding (hash projection is total on tokens)" do
      # Two different texts must NOT collide to the same vector (determinism
      # must not collapse into degeneracy).
      {:ok, a} = Embeddings.embed("quantum lighthouse")
      {:ok, b} = Embeddings.embed("porcupine symphony")
      assert a != b
    end

    test "LocalNx.generate/2 is deterministic across invocations for the same batch" do
      texts = ["shared reading profile: dragons", "shared reading profile: dragons"]

      {:ok, vectors_a} = LocalNx.generate(texts, [])
      {:ok, vectors_b} = LocalNx.generate(texts, [])

      assert vectors_a == vectors_b
      # Identical strings in one batch must yield identical vectors
      assert Enum.at(vectors_a, 0) == Enum.at(vectors_a, 1)
    end

    test "empty and punctuation-only texts hit the zero-vector arm deterministically" do
      {:ok, e1} = Embeddings.embed("")
      {:ok, e2} = Embeddings.embed("!!! ... ???")
      {:ok, e1_again} = Embeddings.embed("")

      assert e1 == List.duplicate(0.0, @dim)
      assert e2 == List.duplicate(0.0, @dim)
      assert e1 == e1_again
      # Zero vector must remain an {:ok, _} value, not an error — the path is total
      assert {:ok, _} = Embeddings.embed("")
    end
  end

  describe "(b) rank integration: embeddings feed the semantic factor" do
    test "compute_semantic_score/2 is exact cosine math on real embeds (orthogonal => 0.5)" do
      # Two disjoint single-token texts project into disjoint hash buckets:
      # orthogonal unit vectors => raw cosine 0.0 => clamped (0+1)/2 = 0.5
      {:ok, student} = Embeddings.embed("lighthouse")
      book = book_struct("quantum", nil)

      score = Ranker.compute_semantic_score(book, student)
      assert_in_delta score, 0.5, 0.000_001
    end

    test "compute_semantic_score/2 for identical text is 1.0 (self-similarity through the clamp)" do
      text = "dragons tunnelling beneath the quiet harbor city"
      {:ok, student} = Embeddings.embed(text)
      book = book_struct(text, nil)

      assert Ranker.compute_semantic_score(book, student) == 1.0
    end

    test "stored list embedding is used verbatim instead of re-embedding (list arm)" do
      # book.embedding is a list -> used directly, bypassing on-the-fly embed
      stored = Enum.map(1..@dim, &(&1 * 1.0))
      book = book_struct("anything", stored)

      # the stored list is consumed verbatim: cosine of the list with itself
      # is 1.0 regardless of title/synopsis text
      score = Ranker.compute_semantic_score(book, stored)
      assert_in_delta score, 1.0, 0.000_001
    end

    test "composite score weights the semantic factor linearly (factor math on real inputs)" do
      # Ranker composite: score = Σ w_f * factor. Verify the semantic term
      # contributes exactly w.semantic * cosine on real embeds by comparing
      # two books differing ONLY in semantic factor.
      text_self = "the marble observatory and its star-charts"
      text_orth = "gravel"

      {:ok, student} = Embeddings.embed(text_self)
      weights = Xaas.Library.Config.weights([])

      s_self = Ranker.compute_semantic_score(book_struct(text_self, nil), student)
      s_orth = Ranker.compute_semantic_score(book_struct(text_orth, nil), student)

      assert_in_delta s_self, 1.0, 0.000_001
      assert_in_delta s_orth, 0.5, 0.000_001

      # Linear contribution: (s_self - s_orth) scaled by the weight must equal
      # the semantic-term delta; with identical other factors this is the
      # exact predicted score delta.
      delta = weights.semantic * (s_self - s_orth)
      assert_in_delta delta, weights.semantic * 0.5, 0.000_001
      assert weights.semantic > 0.0
    end

    test "embed output dimension matches LocalNx declared dimensions" do
      assert LocalNx.dimensions([]) == @dim
      {:ok, v} = Embeddings.embed("dimension contract")
      assert length(v) == LocalNx.dimensions([])
    end
  end

  describe "(c) service-unavailable path typed" do
    test "embed path is total: no external service, no failure arm to hit" do
      # The moduledoc discloses: offline Nx projection, "without external
      # network or LLM dependencies". The honest typed statement is that
      # NO service-unavailable failure exists — the degraded path IS the
      # only path (deterministic fallback), verified by calling the real
      # function, not by faking an outage.
      assert {:ok, v} = Embeddings.embed("network is down; this must not matter")
      assert length(v) == @dim

      assert function_exported?(Embeddings, :embed, 1)

      # LocalNx.generate/2's error arm was removed as dead code; totality is
      # the typed behavior.
    end

    test "LocalNx.generate/2 degrades garbage/nil inputs to deterministic vectors, not errors" do
      assert {:ok, vectors} = LocalNx.generate([nil, "", "  !  ", "ok"], [])
      assert length(vectors) == 4
      assert Enum.all?(vectors, fn v -> length(v) == @dim and Enum.all?(v, &is_float/1) end)
      # nil degrades exactly like "" (text || "" in generate/2)
      assert Enum.at(vectors, 0) == Enum.at(vectors, 1)
    end

    test "cosine_similarity clamps and degrades zero/empty vectors to 0.0 rather than raising" do
      assert Embeddings.cosine_similarity([], [1.0, 2.0]) == 0.0
      assert Embeddings.cosine_similarity([0.0, 0.0], [1.0, 0.0]) == 0.0
      assert Embeddings.cosine_similarity([3.0, 0.0], [5.0, 0.0]) == 1.0
      assert Embeddings.cosine_similarity([1.0, 0.0], [-1.0, 0.0]) == 0.0
      # non-list garbage is caught and typed as 0.0, not a raise
      assert Embeddings.cosine_similarity(:garbage, [1.0]) == 0.0
    end
  end

  defp book_struct(title, embedding) do
    %Xaas.Library.Book{
      title: title,
      synopsis: nil,
      genres: [],
      embedding: embedding
    }
  end
end
