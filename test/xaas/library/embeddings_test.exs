defmodule Xaas.Library.EmbeddingsTest do
  @moduledoc """
  Tests for Xaas.Library.Embeddings — the disclosed deterministic, non-LLM
  Nx-based semantic vector substitution (see docs/case-studies/next-read/README.md).
  Exercises the real Nx math directly; nothing here is mocked.
  """
  use ExUnit.Case, async: true

  alias Xaas.Library.Embeddings

  describe "embed/1" do
    test "is deterministic: same text yields the same vector" do
      text = "the quick brown fox jumps over the lazy dog"

      assert {:ok, vec_a} = Embeddings.embed(text)
      assert {:ok, vec_b} = Embeddings.embed(text)

      assert vec_a == vec_b
    end

    test "returns a 384-dimensional vector of floats" do
      assert {:ok, vec} = Embeddings.embed("a book about elixir and phoenix")
      assert length(vec) == 384
      assert Enum.all?(vec, &is_float/1)
    end

    test "different texts produce different vectors" do
      assert {:ok, vec_a} = Embeddings.embed("space exploration and rocket science")
      assert {:ok, vec_b} = Embeddings.embed("medieval european history")

      assert vec_a != vec_b
    end

    test "handles an empty string without error" do
      assert {:ok, vec} = Embeddings.embed("")
      assert length(vec) == 384
      assert Enum.all?(vec, &(&1 == 0.0))
    end

    test "handles a single word" do
      assert {:ok, vec} = Embeddings.embed("dragons")
      assert length(vec) == 384
      # A single-token vector is L2-normalized, so its norm is ~1.0.
      norm = vec |> Enum.map(&(&1 * &1)) |> Enum.sum() |> :math.sqrt()
      assert_in_delta norm, 1.0, 1.0e-6
    end

    test "repeating the exact same text is direction-invariant under L2 normalization" do
      # Real, correct math (not a hardcoding bug): compute_semantic_vector/2
      # buckets every token occurrence into the same dimension with the same
      # per-token value, so repeating the identical text scales every
      # component by the same uniform factor (2x). L2 normalization divides
      # by the vector's own norm, so a uniform scalar multiple cancels out
      # exactly -- "wizard" and "wizard wizard" land on the same normalized
      # vector because they carry the same *relative* token content, which
      # is exactly what a bag-of-words cosine-similarity embedding should
      # do. The prior version of this test asserted the opposite and was a
      # wrong assumption about the implementation, not a real bug in embed/1.
      assert {:ok, once} = Embeddings.embed("wizard")
      assert {:ok, twice} = Embeddings.embed("wizard wizard")

      assert once == twice
    end

    test "different token content produces a different normalized vector" do
      assert {:ok, wizard} = Embeddings.embed("wizard")
      assert {:ok, dragon} = Embeddings.embed("dragon")

      assert wizard != dragon
    end
  end

  describe "cosine_similarity/2" do
    test "identical vectors score ~1.0" do
      assert {:ok, vec} = Embeddings.embed("a story about dragons and magic")

      assert_in_delta Embeddings.cosine_similarity(vec, vec), 1.0, 1.0e-6
    end

    test "similarity between two embedded texts is deterministic across runs" do
      assert {:ok, vec_a} = Embeddings.embed("science fiction novel about mars colonization")
      assert {:ok, vec_b} = Embeddings.embed("romance novel set in paris")

      sim_1 = Embeddings.cosine_similarity(vec_a, vec_b)
      sim_2 = Embeddings.cosine_similarity(vec_a, vec_b)

      assert sim_1 == sim_2
    end

    test "orthogonal unit vectors score at the midpoint (0.5) after [0,1] remapping" do
      dim = 384
      vec_a = List.duplicate(0.0, dim) |> List.replace_at(0, 1.0)
      vec_b = List.duplicate(0.0, dim) |> List.replace_at(1, 1.0)

      assert_in_delta Embeddings.cosine_similarity(vec_a, vec_b), 0.5, 1.0e-6
    end

    test "opposite vectors score ~0.0 after remapping" do
      dim = 384
      vec_a = List.duplicate(0.0, dim) |> List.replace_at(0, 1.0)
      vec_b = List.duplicate(0.0, dim) |> List.replace_at(0, -1.0)

      assert_in_delta Embeddings.cosine_similarity(vec_a, vec_b), 0.0, 1.0e-6
    end

    test "dissimilar real texts score lower than identical text against itself" do
      assert {:ok, vec_a} = Embeddings.embed("cooking recipes for italian pasta dishes")
      assert {:ok, vec_b} = Embeddings.embed("quantum physics and string theory research")

      self_sim = Embeddings.cosine_similarity(vec_a, vec_a)
      cross_sim = Embeddings.cosine_similarity(vec_a, vec_b)

      assert cross_sim < self_sim
    end

    test "returns 0.0 when either vector is empty" do
      assert Embeddings.cosine_similarity([], [1.0, 2.0]) == 0.0
      assert Embeddings.cosine_similarity([1.0, 2.0], []) == 0.0
      assert Embeddings.cosine_similarity([], []) == 0.0
    end

    test "returns 0.0 when either vector is all zeros" do
      dim = 384
      zero_vec = List.duplicate(0.0, dim)
      vec = List.duplicate(0.0, dim) |> List.replace_at(0, 1.0)

      assert Embeddings.cosine_similarity(zero_vec, vec) == 0.0
      assert Embeddings.cosine_similarity(zero_vec, zero_vec) == 0.0
    end

    test "falls back to 0.0 for non-list arguments" do
      assert Embeddings.cosine_similarity(nil, [1.0]) == 0.0
      assert Embeddings.cosine_similarity("not a list", [1.0]) == 0.0
    end
  end
end
